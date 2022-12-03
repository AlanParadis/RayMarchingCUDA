#ifndef RAYMARCHING_H_
#define RAYMARCHING_H_

#include <GL/glew.h>
#include <GL/wglew.h>
#include <GL/freeglut.h>
#include <SFML/System.hpp>
#include <SFML/Window.hpp>
#include <SFML/Graphics.hpp>

#include "CUDAHelper.cuh"
#include "Settings.cuh"

namespace rm
{
    __device__
    inline float DistanceFromPlane(float3 p, float h)
    {
        return p.y - h;
    }

    __device__
    inline float SmoothMin(float dstA, float dstB, float k) {
        float h = std::fmaxf(k - abs(dstA - dstB), 0) / k;
        return std::fminf(dstA, dstB) - h * h * h * k * (1.0f / 6.0f);
    }
    
    // params:
    // p: arbitrary point in 3D space
    // c: the center of our sphere
    // r: the radius of our sphere
    __device__
    inline float DistanceFromSphere(float3 p, float3 c, float r)
    {
        return length(p - c) - r;
    }

    struct Camera
    {
        float3 pos;
        float3 dir;
        float invhalffov;
        float maxdist = MAXIMUM_TRACE_DISTANCE;
        float3 up;
        float3 right;
    };

    class RayMarching
    {
    private:
        Camera cam;
        __device__
        float MapTheWorld(float3 _p);
        __device__
        float3 CalculateNormal(float3 _p);
        __device__ 
        float3 Raymarch(float3 ro, float3 rd);

        sf::Vector2i lastMousePos;

    public:
        void Init(sf::RenderWindow* _window);
        void Update(sf::RenderWindow* _window, float _dt);
        __device__ 
        float3 Render(int _pX, int _pY);
        void Shutdown();
    };
}

#endif  /* !RAYMARCHING_H_ */
