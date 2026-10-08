void GetCrossSampleUVs_float(float4 uv, float2 texelSize, float offset, out float2 uvFull, out float2 uvTopRight, out float2 uvBottomLeft, out float2 uvTopLeft, out float2 uvBottomRight)
{
    uvFull = uv;
    uvTopRight = uv.xy + float2(texelSize.x, texelSize.y) * offset;
    uvTopLeft = uv.xy + float2(-texelSize.x * offset, texelSize.y * offset);
    uvBottomRight = uv.xy + float2(texelSize.x * offset, -texelSize.y * offset);
    uvBottomLeft = uv.xy - float2(texelSize.x, texelSize.y) * offset;
}