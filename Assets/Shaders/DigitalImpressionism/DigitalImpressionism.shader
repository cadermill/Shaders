Shader"Custom/DigitalImpressionism"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white"

        _CellSize("Cell Size", float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

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
                float4 positionOS : TEXCOORD1;
                float3 normalOS : TEXCOORD2; // object space normal
                float3 positionWS : TEXCOORD3; // world space position
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;

                float _CellSize;
            CBUFFER_END

            // Function to randomize the cell center based on the cell coordinates
            // Returns the coordinates of the cell center
            float3 randomizeCellCenter(float3 cell)
            {
                float3 randomOffset = frac(sin(dot(cell, float3(12.9898, 78.233, 37.719))) * 43758.5453); // Pseudo-random offset based on cell coordinates
                return float3(cell + randomOffset); // Offset between 0 and 1 in each dimension
            }

            // Voronoi noise function
            // Returns the cell's position in object space and minimum distance to the nearest cell center
            float4 voronoiNoise(float3 pos)
            {
                float3 cell = floor(pos); // Floor object position to get the cell coordinates

                float minDist = 1e10; // Initialize minimum distance to a large value
                float3 closestCell = float3(0, 0, 0); // Initialize closest cell
                [unroll]
                for (int x = -1; x <= 1; x++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int z = -1; z <= 1; z++)
                        {
                            float3 cellCenter = randomizeCellCenter(cell + float3(x, y, z)); // Get the cell center for neighboring cells
                            float dist = distance(pos, cellCenter);
                            if (dist < minDist) 
                            { 
                                minDist = dist; 
                                closestCell = cellCenter;
                            }
                        }
                    }
                }
                return float4(closestCell, minDist); // Return the closest cell center and the distance to it
            }

            float3 getLighting(float3 normal, Light light)
            {
                float3 lightDir = normalize(light.direction); // Get the direction of the main light
                float diffuse = saturate(dot(normal, lightDir)); // Calculate the diffuse lighting based on the normal and light direction
                
                float3 ambient = SampleSH(normal); // Sample the ambient lighting using spherical harmonics

                return light.color * (diffuse + ambient); // Multiply the light color by the diffuse lighting and add ambient
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionOS = IN.positionOS; // Pass the object space position to the fragment shader
                OUT.normalOS = IN.normalOS; // Pass the object space normal to the fragment shader
                OUT.positionWS = GetVertexPositionInputs(IN.positionOS).positionWS;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
    
                float3 pos = IN.positionOS.xyz / _CellSize; // Allow cell size to be adjusted via a property
                float4 noise = voronoiNoise(pos); 

                float3 normalOS = normalize(noise.xyz - IN.positionOS.xyz); // Calculate the normal based on the closest cell center
                float3 normalWS = TransformObjectToWorldNormal(normalOS); // Transform the normal to world space
                Light mainLight = GetMainLight(); // Get the main light in the scene
                float3 lightColor = getLighting(normalWS, mainLight);

                // Additional lights
                for (int i = 0; i < GetAdditionalLightsCount(); i++)
                {
                    Light additionalLight = GetAdditionalLight(i, IN.positionWS, 1);
                    lightColor += getLighting(normalWS, additionalLight);
                }

                return float4(color.rgb * lightColor, color.a); // Multiply the base color by the diffuse lighting
}
            ENDHLSL
        }
    }
}
