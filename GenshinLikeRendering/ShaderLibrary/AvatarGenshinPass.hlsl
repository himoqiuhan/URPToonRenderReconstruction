#ifndef CUSTOM_AVATAR_GENSHIN_PASS_INCLUDED
#define CUSTOM_AVATAR_GENSHIN_PASS_INCLUDED

#include "../ShaderLibrary/AvatarGenshinInput.hlsl"
#include "../ShaderLibrary/AvatarLighting.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float4 vertexColor : COLOR;
    float2 uv : TEXCOORD0;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION_WS;
    float3 normalWS : VAR_NORMAL_WS;
    float2 uv : VAR_BASE_UV;
    float4 vertexColor : COLOR;
};

Varyings GenshinStyleVertex(Attributes input)
{
    Varyings output;
    VertexPositionInputs vertexPositionInputs = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs vertexNormalInputs = GetVertexNormalInputs(input.normalOS.xyz, input.tangentOS);
    output.positionCS = vertexPositionInputs.positionCS;
    output.positionWS = vertexPositionInputs.positionWS;
    output.normalWS = vertexNormalInputs.normalWS;
    output.uv = input.uv;
    output.vertexColor = input.vertexColor;
    return output;
}

half4 GenshinStyleFragment(Varyings input) : SV_Target
{
    half4 mainTexCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _MainTexColoring;
    
    Light mainLight = GetMainLight();
    float3 mainLightDirection = normalize(mainLight.direction);

//区分面部和身体的渲染    
#if defined(_RENDERTYPE_BODY)
        float emissionFactor = 1.0;
    #if defined(_MAINTEXALPHAUSE_EMISSION)
        emissionFactor = _EmissionScaler * mainTexCol.a;
    #elif defined(_MAINTEXALPHAUSE_FLICKER)
        emissionFactor = _EmissionScaler * mainTexCol.a * (0.5 * sin(_Time.y) + 0.5);
    #elif defined(_MAINTEXALPHAUSE_ALPHATEST)
        clip(mainTexCol.a - _MainTexCutOff);
        emissionFactor = 0;
    #else
        emissionFactor = 0;
    #endif

    half4 ilmTexCol = SAMPLE_TEXTURE2D(_ilmTex, sampler_ilmTex, input.uv);

    float halfLambert = 0.5 * dot(mainLightDirection, input.normalWS) + 0.5;
    float AOMask = step(0.02, ilmTexCol.g);
    float brightAreaMask = AOMask * halfLambert;

    //Diffuse
    float2 rampUV;
    //对原神Ramp X轴处理：
    //以LightArea作为阈值，通过AO和halfLambert来控制Ramp明亮交界的位置
    rampUV.x = min(0.99, smoothstep(0.001, 1.0 - _LightArea, brightAreaMask));
    //对原神Ramp Y轴处理的全新理解：
    //1.首先，原神的Ramp采样是基于左上角为(0，0)的，原因猜测是网上拿到的Ramp资源是基于PC截帧获取的，DX平台默认的贴图是以左上角为UV空间的原点；
    //而Unity中默认的UV空间原点是左下角，所以需要在Y轴上做翻转
    //2.基于ilm贴图的A通道和Ramp图的适配性，以及结合游戏内的表现，我猜测存在一个_RampCount来对ilm贴图A通道读取Ramp行序号的信息进行缩放
    rampUV.y = 1.0 - saturate(ilmTexCol.a) / _RampCount * 0.5 + _UseCoolShadowColorOrTex * 0.5 - 0.001;
    half3 rampTexCol = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampUV).rgb;    
    
    //以上获取的Shadow Color颜色对固有阴影的颜色处理不够深，所以通过ShadowColor进一步调色
    half3 darkShadowColor = lerp(_DarkShadowColor.rgb, _CoolDarkShadowColor.rgb, _UseCoolShadowColorOrTex) * rampTexCol;
    #if !defined(_USERAMPLIGHTAREACOLOR_ON)
        //区分使用Ramp的最右侧作为亮部颜色和使用自定义亮部颜色两种情况，使用自定义时可以获取额外的亮部二分ramp条
        //进一步处理brightAreaMask，来获取亮部区域（非Ramp区）的遮罩，参数_ShadowRampWidth影响最接近亮部的ramp条的宽度
        brightAreaMask = step(1.0 - _LightArea, brightAreaMask + (1.0 - _ShadowRampWidth) * 0.1);
        rampTexCol = lerp(rampTexCol, _LightAreaColorTint, brightAreaMask);
    #endif
    half3 ShadowColorTint = lerp(darkShadowColor.rgb, rampTexCol, AOMask);
    ShadowColorTint = lerp(_NeckColor.rgb, ShadowColorTint, input.vertexColor.b);
    half3 diffuseColor = ShadowColorTint * mainTexCol.rgb;

    //Specular
    float3 viewDirectionWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
    float3 halfDirectionWS = normalize(viewDirectionWS + mainLightDirection);
    float hdotl = max(dot(halfDirectionWS, input.normalWS.xyz), 0.0);
    //非金属高光
    float nonMetalSpecular = step(1.0 - 0.5 * _NonMetalSpecArea, pow(hdotl, _Shininess)) * ilmTexCol.r;
    //金属高光
    //ilmTexture中，r通道控制Blinn-Phong高光的系数，b通道控制Metal Specular的范围
    float2 normalCS = TransformWorldToHClipDir(input.normalWS.xyz).xy * 0.5 + float2(0.5, 0.5);
    float metalTexCol = saturate(SAMPLE_TEXTURE2D(_MetalTex, sampler_MetalTex, normalCS)).r * _MTMapBrightness;
    float metalBlinnPhongSpecular = pow(hdotl, _MTShininess) * ilmTexCol.r;
    float metalSpecular = ilmTexCol.b * metalBlinnPhongSpecular * metalTexCol;
    half3 specularColor = (metalSpecular * _MTSpecularScale + nonMetalSpecular) * diffuseColor;
    half3 color = specularColor * _SpecMulti + diffuseColor;

    //Rim Light
    float rimLightDepthDiff = GetRimLightDepthDiff(input.positionCS.xyz,
                                                   normalize(TransformWorldToHClipDir(input.normalWS, true)).xy,
                                                   _RimLightWidth * (1 + saturate(hdotl) * _RimLightWidthSpecularScaler * 2.0));
                                                    //受specular影响的边缘光宽度
    //基于Rim Light获得的边缘光区域深度差别值，进行进一步处理
    //因为边缘光的计算是基于模型扩大后的深度差值的，游戏中边缘光随着深度差值进行插值，但是如果直接用diff去进行插值，得到的效果不够好，不同区域之间深度diff差异太大
    //所以对DepthDiff进一步处理，得到的结果是减小了大Diff值与小Diff值之间的差距，得到比较平滑的Rim Light效果
    float rimLightMask = 0.75 * (saturate(rimLightDepthDiff) * 0.5 + 0.15 * step(0.1, rimLightDepthDiff));

    //最终的合成
    color = lerp(color, diffuseColor * (1.0 + _RimLightStrength * 2.0), rimLightMask);

    color *= 1 + emissionFactor;
    
#else

    //获取向量信息
    //unity_objectToWorld可以获取世界空间的方向信息，构成如下：
    // unity_ObjectToWorld = ( right, back, left)
    float3 rightDirectionWS = unity_ObjectToWorld._11_21_31;
    float3 backDirectionWS = unity_ObjectToWorld._13_23_33;
    float rdotl = dot(normalize(mainLightDirection.xz), normalize(rightDirectionWS.xz));
    float fdotl = dot(normalize(mainLightDirection.xz), normalize(backDirectionWS.xz));

    //SDF面部阴影
    //将ilmTexture看作光源的数值，那么原UV采样得到的图片是光从角色左侧打过来的效果，且越往中间，所需要的亮度越低。lightThreshold作为点亮区域所需的光源强度
    float2 ilmTextureUV = rdotl < 0.0 ? input.uv : float2(1.0 - input.uv.x, input.uv.y);
    float lightThreshold = 0.5 * (1.0 - fdotl);
    
    half4 ilmTexCol = SAMPLE_TEXTURE2D(_ilmTex, sampler_ilmTex, ilmTextureUV);
    half4 metalTexCol = SAMPLE_TEXTURE2D(_MetalTex, sampler_MetalTex, input.uv);

    #if defined(_USEFACELIGHTMAPCHANNEL_R)
        float lightStrength = ilmTexCol.r;
    #else
        float lightStrength = ilmTexCol.a;
    #endif
    
    float brightAreaMask = step(lightThreshold, lightStrength);

    half3 brightAreaColor = mainTexCol.rgb * _LightAreaColorTint.rgb;
    half3 shadowAreaColor = mainTexCol.rgb * lerp(_DarkShadowColor.rgb, _CoolDarkShadowColor.rgb, _UseCoolShadowColorOrTex);

    half3 lightingColor = lerp(shadowAreaColor, brightAreaColor, brightAreaMask) * _MainTexColoring.rgb;

    //边缘光计算
    float rimLightDepthDiff = GetRimLightDepthDiff(input.positionCS.xyz,
                                                   normalize(TransformWorldToHClipDir(input.normalWS, true)).xy,
                                                   _RimLightWidth); 
    float rimLightMask = 0.75 * (saturate(rimLightDepthDiff) * 0.5 + 0.15 * step(0.1, rimLightDepthDiff));
    //光照区域合成
    lightingColor = lerp(lightingColor, lightingColor * (1.0 + _RimLightStrength * 2.0), rimLightMask);

    //遮罩贴图的rg通道区分受光照影响的区域和不受影响的区域
    half3 color = lerp(mainTexCol.rgb, lightingColor, metalTexCol.r);

#endif

    return half4(color, 1.0);
}

#endif
