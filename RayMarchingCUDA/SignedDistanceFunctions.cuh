#ifndef SDF_H_
#define SDF_H_

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
    // params:
    // p: arbitrary point in 3D space
    // h: height of the plane
    __device__
    inline float DistanceFromPlane(float3 p, float h)
    {
        return p.y - h;
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

}
#endif  /* !SDF_H_ */