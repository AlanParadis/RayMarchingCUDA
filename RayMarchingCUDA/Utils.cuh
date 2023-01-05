#ifndef UTILS_H_
#define UTILS_H_

#include <GL/glew.h>
#include <GL/wglew.h>
#include <GL/freeglut.h>
#include <SFML/System.hpp>
#include <SFML/Window.hpp>
#include <SFML/Graphics.hpp>

#include "CUDAHelper.cuh"
#include "Settings.cuh"

// get sign function
#define sign(x) ((x > 0.f) - (x < 0.f))
// clamp macro
#define clamp(x, a, b) (x < a ? a : (x > b ? b : x))

namespace rm
{ 
    __device__
    inline float SmoothMin(float dstA, float dstB, float k) {
        float h = std::fmaxf(k - abs(dstA - dstB), 0.f) / k;
        return std::fminf(dstA, dstB) - h * h * h * k * (1.0f / 6.0f);
    }


    //absolute value of float3
    __device__ __host__
    inline float3 fabsf(float3 v)
    {
        return make_float3(abs(v.x), abs(v.y), abs(v.z));
    }

    //float3  float mod
    __device__ __host__
    inline float3 fmodf(float3 a, float b)
    {
        return make_float3(std::fmodf(a.x, b), std::fmodf(a.y, b), std::fmodf(a.z, b));
    }

    // float3 max
    __device__ float3 fmaxf(float3 a, float3 b)
    {
        return make_float3(std::fmaxf(a.x, b.x), std::fmaxf(a.y, b.y), std::fmaxf(a.z, b.z));
    }

    __device__
    inline float3 lerp(float3 a, float3 b, float t)
    {
        return (1.0f - t) * a + t * b;
    }
}
#endif  /* !UTILS_H_ */