// 3DVoronoiNoise.hlsl

// ------------------------------------------------------------
// Randomize cell center
// Returns:
//   xyz = randomized cell center
//   w   = unique random ID
// ------------------------------------------------------------
float4 RandomizeCellCenter(float3 cell)
{
    float3 randomOffset =
        frac(sin(dot(cell, float3(12.9898, 78.233, 37.719))) * 43758.5453);

    float randomId =
        frac(sin(dot(sin(cell), float3(12.9898, 78.233, 37.719))) * 43758.5453);

    return float4(cell + randomOffset, randomId);
}


// ------------------------------------------------------------
// 3D Voronoi
// Returns:
//   x = distance to nearest cell center
//   y = random ID of nearest cell
// ------------------------------------------------------------
float2 VoronoiNoise(float3 pos, float cellSize)
{
    float3 scaledPos = pos / cellSize;
    
    float3 cell = floor(scaledPos);

    float minDist = 1e10;
    float4 closestCell = float4(0, 0, 0, 0);

    [unroll]
    for (int x = -1; x <= 1; x++)
    {
        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            [unroll]
            for (int z = -1; z <= 1; z++)
            {
                float4 cellCenter =
                    RandomizeCellCenter(cell + float3(x, y, z));

                float dist = distance(scaledPos, cellCenter.xyz);

                if (dist < minDist)
                {
                    minDist = dist;
                    closestCell = cellCenter;
                }
            }
        }
    }

    return float2(minDist, closestCell.w);
}


// ------------------------------------------------------------
// Shader Graph Custom Function wrapper
// ------------------------------------------------------------
void VoronoiNoise_float(
    float3 Position,
    float CellSize,
    out float Distance,
    out float Cells)
{
    float2 result = VoronoiNoise(Position, CellSize);

    Distance = result.x;
    Cells = result.y;
}