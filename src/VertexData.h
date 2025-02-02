#include <simd/simd.h>
// #include "AAPLMathUtilities.h"

struct VertexData {
#ifndef METAL_SHADER
    float position[4]; // float4
    float texCoord[2]; // float2
#else
    float4 position;
    float2 texCoord;
#endif
};

struct TransformationData {
#ifndef METAL_SHADER
    matrix_float4x4 modelMat;
    matrix_float4x4 viewMat;
    matrix_float4x4 perspMat;
#else
    float4x4 modelMat;
    float4x4 viewMat;
    float4x4 perspMat;
#endif
};
