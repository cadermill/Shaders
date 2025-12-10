Shader "Custom/CelShader"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white"

        _Smoothness ("Smoothness", Float) = 0.5
        _RimThreshold ("Rim Threshold", Float) = 0.5

        _EdgeDiffuse("Edge Diffuse", Float) = 1.0
        _EdgeSpecular("Edge Specular", Float) = 1.0
        _EdgeSpecularOffset("Edge Specular Offset", Float) = 0.0
        _EdgeShadowAttenuation("Edge Shadow Attenuation", Float) = 0.9
        _EdgeDistanceAttenuation("Edge Distance Attenuation", Float) = 0.1
        _EdgeRim("Edge Rim", Float) = 1.0
        _EdgeRimOffset("Edge Rim Offset", Float) = 0.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS         // added these
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE // to support
            #pragma multi_compile_fragment _ _SHADOWS_SOFT      // shadow implementation
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;

                float3 normalOS : NORMAL; // object space normal
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;

                float3 normalWS : TEXCOORD1; // world space normal
                float3 viewDirWS : TEXCOORD2; // world space view direction
                float4 shadowCoord : TEXCOORD3; // shadow coordinates
                float3 positionWS : TEXCOORD4; // world space position
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;

                float _Smoothness;
                float _RimThreshold;

                float _EdgeDiffuse;
                float _EdgeSpecular;
                float _EdgeSpecularOffset;
                float _EdgeShadowAttenuation;
                float _EdgeDistanceAttenuation;
                float _EdgeRim;
                float _EdgeRimOffset;
            CBUFFER_END

            /*  lighting notes
            *   diffuse --> dot product of the surface normal and the vector towards the light source
            *   specular --> dot product of the refleciton vector and vector towards the viewer to the power of a shininess constant
            *   blinn-phong specular --> dot product of the normal and the light and viewer vectors combined
            *   rim --> 1 - dot product of normal and view vectors, brighter if there is a bigger angle between camera and normal
            */

            // cel shaded lighting
            float3 GetLighting(Light light, float3 normal, float3 view, half shadow)
            {
                float shadowAttenuation = shadow;
                float distanceAttenuation = smoothstep(0.0, _EdgeDistanceAttenuation, light.distanceAttenuation);
                shadowAttenuation = smoothstep(0.0, _EdgeShadowAttenuation, shadowAttenuation); // smoothstep for cel shaded look
                float attenuation = distanceAttenuation * shadowAttenuation;

                float diffuse = saturate(dot(normal, light.direction)); // diffuse lighting calculation clamped between 0.0 and 1.0
                diffuse *= attenuation; // exclude lighting where there are shadows

                float3 h = SafeNormalize(light.direction + view); // half view dir based on direction and view vectors
                float specular = saturate(dot(normal, h)); // specular calculation clamped between 0.0 and 1.0
                float shininess = pow(clamp(_Smoothness, 0, 1), 2.0) * 256.0; // shininess calculation
                specular = pow(specular, shininess); // final specular calculated to the power of shininess constant
                specular *= diffuse * _Smoothness; // prevents the specular lighting from showing in shaded area
                
                float rim = 1 - dot(view, normal); // rim calculation
                rim *= pow(diffuse, _RimThreshold); // change rim brightness

                // cell shaded
                diffuse = smoothstep(0.0, _EdgeDiffuse, diffuse);
                specular = _Smoothness * smoothstep((1 - _Smoothness) * _EdgeSpecular + _EdgeSpecularOffset, _EdgeSpecular + _EdgeSpecularOffset, specular);
                rim = _Smoothness * smoothstep(_EdgeRim - 0.5 * _EdgeRimOffset, _EdgeRim + 0.5 * _EdgeRimOffset, rim);

                float3 finalLight = diffuse + max(specular, rim);
                float3 ambient = SampleSH(normal);
                finalLight += ambient;
                return light.color * finalLight; // multiply by light color
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

                OUT.normalWS = GetVertexNormalInputs(IN.normalOS).normalWS; // convert normal to world space
                float3 positionWS = GetVertexPositionInputs(IN.positionOS).positionWS;
                OUT.positionWS = positionWS;
                OUT.viewDirWS = GetWorldSpaceViewDir(positionWS); // get the world space view
                OUT.shadowCoord = TransformWorldToShadowCoord(positionWS); // get shadow coords

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normal = normalize(IN.normalWS);
                float3 view = normalize(IN.viewDirWS);
                float4 shadow = IN.shadowCoord;
                Light light = GetMainLight(shadow); // gets the main light in the scene
                float3 color = GetLighting(light, normal, view, light.shadowAttenuation);

                // add the color of every other light in the scene
                int lightCount = GetAdditionalLightsCount();
                for (int i = 0; i < lightCount; i++)
                {
                    light = GetAdditionalLight(i, IN.positionWS);
                    shadow = AdditionalLightRealtimeShadow(i, IN.positionWS);
                    color += GetLighting(light, normal, view, shadow);
                }

                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;

                return half4(baseColor.rgb * color, baseColor.a); // multiply the light by the base color (light is vec3 while col is vec4)
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return 0; 
            }
            ENDHLSL
        }
    }
}
