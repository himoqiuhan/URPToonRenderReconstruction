Shader "QiuHanMMDRender/Genshin/GenshinAvatar"
{
    Properties
    {
        [Header(General)]
        [KeywordEnum(Body, Face)]_RenderType("Render Type", float) = 0.0
        [KeywordEnum(R, A)]_UseFaceLightMapChannel("Use Face Lightmap Channel", float) = 1.0
        [Toggle]_UseCoolShadowColorOrTex("Use Cool Shadow", float) = 0.0
        [KeywordEnum(None,Flicker,Emission,AlphaTest)]_MainTexAlphaUse("Diffuse Texture Alpha Use", float) = 0.0
        _MainTexCutOff("Cut Off", Range(0.0, 1.0)) = 0.5
        _EmissionScaler("Emission Scaler", Range(1.0, 10.0)) = 5.0
        [Enum(UnityEngine.Rendering.CullMode)]_BasePassCullMode("Base Pass Cull Mode", Float) = 0.0

        [Header(Lighting)]
        _MainTex("Diffuse Texture", 2D) = "white"{}
        _ilmTex("ilm Texture", 2D) = "white"{}
        _RampTex("Ramp Texture", 2D) = "white"{}
        [Toggle]_UseRampLightAreaColor("Use Ramp Light Area Color", float) = 0.0
        _LightArea("Light Area", Range(0.0, 1.0)) = 0.55
        _LightAreaColorTint("Light Area Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _RampCount("Ramp Count", Int) = 3
        _ShadowRampWidth("Shadow Ramp Width", Range(0.0, 1.0)) = 1.0
        _HairShadowDistance("Hair Shadow Distance", Range(0.0, 1.0)) = 0.5
        _MainTexColoring("Main Texture Coloring", Color) = (1.0, 1.0, 1.0, 1.0)
        _DarkShadowColor("Dark Shadow Color Tint", Color) = (0.75, 0.75, 0.75, 1.0)
        _CoolDarkShadowColor("Cool Dark Shadow Color Tint", Color) = (0.5, 0.5, 0.65, 1.0)
        _NeckColor("Neck Color Tint", Color) = (0.75, 0.75, 0.75, 1.0)
        
        [Header(Specular)]
        _MetalTex("Metal Texture", 2D) = "Gray"{}
        _MTMapBrightness("Metal Map Brightness", Range(0.0, 10.0)) = 3.0
        _MTShininess("Metal Shininess", Range(0.0, 100.0)) = 90.0
        _MTSpecularScale("Metal Specular Scale", Range(0.0, 100.0)) = 15.0
        _Shininess("Shininess", Range(5.0, 20.0)) = 10.0
        _NonMetalSpecArea("Non-metal Spcular Area", Range(0.0, 1.0)) = 0.0
        _SpecMulti("Specular Multiplier", Range(0.0, 1.0)) = 0.2

        [Header(Rim Light)]
        _RimLightWidth("Rim Light Width", Range(0.0, 1.0)) = 0.1
        _RimLightWidthSpecularScaler("Rim Light Width Specular Scaler", Range(0.0, 1.0)) = 0.0
        _RimLightStrength("Rim Light Strength", Range(0.0, 1.0)) = 0.5

        [Header(Outline)]
        _OutlineWidthAdjustScale("Outline Width Adjust Scale", Range(0.0, 1.0)) = 1.0
        _OutlineColor1("Outline Color 1", Color) = (0.0, 0.0, 0.0, 1.0)
        _OutlineColor2("Outline Color 2", Color) = (0.1, 0.1, 0.1, 1.0)
        _OutlineColor3("Outline Color 3", Color) = (0.2, 0.2, 0.2, 1.0)
        _OutlineColor4("Outline Color 4", Color) = (0.3, 0.3, 0.3, 1.0)
        _OutlineColor5("Outline Color 5", Color) = (0.4, 0.4, 0.4, 1.0)
        [KeywordEnum(Null, VertexColor, NormalTexture)]_UseSmoothNormal("Use Smooth Normal From", float) = 0.0

        [Header(Debug)]
        _DebugValue01("Debug Value 0-1", Range(0.0, 1.0)) = 0.0
    }
    SubShader
    {
        HLSLINCLUDE
        #include "../ShaderLibrary/AvatarGenshinInput.hlsl"
        ENDHLSL
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }
        LOD 100

        Pass
        {
            Name "GenshinStyleBasicRender"
            Cull [_BasePassCullMode]
            Tags
            {
                "LightMode"="UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex GenshinStyleVertex
            #pragma fragment GenshinStyleFragment
            #pragma shader_feature_local _ _MAINTEXALPHAUSE_NONE _MAINTEXALPHAUSE_FLICKER _MAINTEXALPHAUSE_EMISSION _MAINTEXALPHAUSE_ALPHATEST
            #pragma shader_feature_local _ _RENDERTYPE_BODY _RENDERTYPE_FACE
            #pragma shader_feature_fragment _ _USEFACELIGHTMAPCHANNEL_R _USEFACELIGHTMAPCHANNEL_A
            #pragma shader_feature_local_fragment _USERAMPLIGHTAREACOLOR_ON
            #include "../ShaderLibrary/AvatarGenshinPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "BackFacingOutline"
            Cull Front
            Tags
            {
                "LightMode"="SRPDefaultUnlit"
            }
            HLSLPROGRAM
            #pragma vertex BackFaceOutlineVertex
            #pragma fragment BackFaceOutlineFragment
            #pragma shader_feature_local _ _USESMOOTHNORMAL_VERTEXCOLOR _USESMOOTHNORMAL_NORMALTEXTURE _USESMOOTHNORMAL_NULL
            #include "../ShaderLibrary/AvatarGenshinOutlinePass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode"="ShadowCaster"
            }
            HLSLPROGRAM
            #pragma vertex ShadowCasterVertex
            #pragma fragment ShadowCasterFragment
            #include "../ShaderLibrary/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode"="DepthOnly"
            }

            ZWrite On
            ColorMask 0
            Cull off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
}