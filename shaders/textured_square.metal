#include <metal_stdlib>
using namespace metal;
using namespace simd;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex VertexOut textured_quad_vert(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.textureCoordinate = in.textureCoordinate;
    return out;
}

fragment float4 textured_quad_frag(VertexOut in [[stage_in]],
                               texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    // Sample the texture to obtain a color
    const float4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    return colorSample;
}

