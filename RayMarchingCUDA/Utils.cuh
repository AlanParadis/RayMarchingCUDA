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

#define PI 3.141592653589f
#define PHI 1.61803398875f

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
    
    // floor
    __device__
    inline float3 floor(float3 v)
    {
        return make_float3(std::floorf(v.x), std::floorf(v.y), std::floorf(v.z));
    }
    
    //fract function
    __device__
    inline float3 fract(float3 v)
    {
        return v - rm::floor(v);
    }

    __device__
    inline float fract(float v)
    {
        return v - std::floor(v);
    }
    
    // floor
    __device__
    inline float2 floor(float2 v)
    {
        return make_float2(std::floorf(v.x), std::floorf(v.y));
    }
    
    //fract function
    __device__
    inline float2 fract(float2 v)
    {
        return v - rm::floor(v);
    }

    //smoothstep
    __device__
        inline float smoothstep(float edge0, float edge1, float x)
    {
        float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
        return t * t * (3.0f - 2.0f * t);
    }

    //glm::mix
    __device__
    inline float mix(float x, float y, float a)
    {
        return x * (1.0f - a) + y * a;
    }
    
}
#endif  /* !UTILS_H_ */