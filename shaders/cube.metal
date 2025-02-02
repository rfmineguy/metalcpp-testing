//
//  cube.metal
//  MetalTutorial
//   https://github.com/wmarti/MetalTutorial/blob/Lesson_2_1/Metal-Tutorial/cube.metal
//

#include <metal_stdlib>
using namespace metal;

#define METAL_SHADER
#include "VertexData.h"

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex VertexOut cube_vertex(uint vertexID [[vertex_id]],
             constant VertexData* vertexData [[buffer(0)]],
             constant TransformationData* transformationData [[buffer(1)]])
{
    VertexOut out;
    out.position = transformationData->perspMat * transformationData->viewMat * transformationData->modelMat * vertexData[vertexID].position;
    out.textureCoordinate = vertexData[vertexID].texCoord;
    return out;
}

fragment float4 cube_fragment(VertexOut in [[stage_in]],
                               texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    const float4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    return colorSample;
}
