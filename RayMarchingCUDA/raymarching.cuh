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
#include "matrix.cuh"

namespace rm
{
    //function that take a point, mat3 and a origin a return the rotated point
    __device__ __host__
    inline float3 RotatePoint(float3 point, mat3 rotation, float3 origin);
    
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
        // time since Raymarching Init
        float time;
        bool isMouseLock;

    public:
        void Init(sf::RenderWindow* _window);
        void Event(sf::RenderWindow* _window, sf::Event* _evt);
        void Update(sf::RenderWindow* _window, float _dt);
        __device__ 
        float3 Render(int _pX, int _pY);
        void Shutdown();
    };
}

#endif  /* !RAYMARCHING_H_ */
