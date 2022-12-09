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
    inline float SmoothMin(float dstA, float dstB, float k);
    
    
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
        Camera camera;
        __device__
        float MapTheWorld(float3 _p);
        __device__
        float3 ApplyBeerLambert(float3 color, float distanceTraveled, float absorptionCoefficient);
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
