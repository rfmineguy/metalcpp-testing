#include <simd/simd.h>

struct VertexData {
    float position[4]; // float4
    float texCoord[2]; // float2
};

struct TransformationData {
    simd_float4 modelMat;
    simd_float4 viewMat;
    simd_float4 perspMat;
};
