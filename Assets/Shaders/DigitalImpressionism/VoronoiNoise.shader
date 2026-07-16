Shader"Custom/VoronoiNoise"
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

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 positionOS : TEXCOORD1;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;

                float _CellSize;
            CBUFFER_END

            // Function to randomize the cell center based on the cell coordinates
            // Returns the coordinates of the cell center and a unique random identifier
            float4 randomizeCellCenter(float3 cell)
            {
                float3 randomOffset = frac(sin(dot(cell, float3(12.9898, 78.233, 37.719))) * 43758.5453); // Pseudo-random offset based on cell coordinates
                float randomId = frac(sin(dot(sin(cell), float3(12.9898, 78.233, 37.719))) * 43758.5453); // Unique random identifier for the cell
                return float4(cell + randomOffset, randomId); // Offset between 0 and 1 in each dimension
            }

            // Voronoi noise function
            // Returns the minimum distance to the nearest cell center and the cell's random identifier
            float2 voronoiNoise(float3 pos)
            {
                float3 cell = floor(pos); // Floor object position to get the cell coordinates

                float minDist = 1e10; // Initialize minimum distance to a large value
                float4 closestCell = float4(0, 0, 0, 0); // Initialize closest cell
                [unroll]
                for (int x = -1; x <= 1; x++)
                {
                    [unroll]
                    for (int y = -1; y <= 1; y++)
                    {
                        [unroll]
                        for (int z = -1; z <= 1; z++)
                        {
                            float4 cellCenter = randomizeCellCenter(cell + float3(x, y, z)); // Get the cell center for neighboring cells
                            float dist = distance(pos, cellCenter.xyz); // Take cell coordinates only
                            if (dist < minDist) 
                            { 
                                minDist = dist; 
                                closestCell = cellCenter;
                            }
                        }
                    }
                }
                return float2(minDist, closestCell.w); // Return the minimum distance and the closest cell center
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionOS = IN.positionOS; // Pass the object space position to the fragment shader
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
    
                float3 pos = IN.positionOS.xyz / _CellSize; // Allow cell size to be adjusted via a property
                float2 noise = voronoiNoise(pos); 
                return float4(noise.y, noise.y, noise.y, 1);
}
            ENDHLSL
        }
    }
}
