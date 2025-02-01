#include <metal_stdlib>
using namespace metal;
using namespace simd;

struct VertexData {
    float4 position;
    float2 textureCoordinate;
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
             constant VertexData* vertexData) {
    VertexOut out;
    out.position = vertexData[vertexID].position;
    out.textureCoordinate = vertexData[vertexID].textureCoordinate;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    // Sample the texture to obtain a color
    const float4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    return colorSample;
}

