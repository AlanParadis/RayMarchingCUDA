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
#include "Utils.cuh"

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
    
    // params:
    // p: arbitrary point in 3D space
    // b: the dimensions of the box
    // returns: the distance between the point and the box
    __device__
    inline float DistanceFromBox(float3 p, float3 b)
    {
        float3 di = fabsf(p) - b;
        float mc = max(di.x, max(di.y, di.z));
        return fmin(mc, length(fmaxf(di, make_float3(0.0f))));
    }

    // params:
    // p: arbitrary point in 3D space
    // returns: the distance between the point and the cross-shaped object
    __device__
    inline float DistanceFromCross(float3 p)
    {
        float da = max(fmax(abs(p.x), abs(p.y)), 0.0f);
        float db = max(fmax(abs(p.y), abs(p.z)), 0.0f);
        float dc = max(fmax(abs(p.z), abs(p.x)), 0.0f);
        return min(da, min(db, dc)) - 1.0f;
    }
    
    // params:
    // p: arbitrary point in 3D space
    __device__
    float MengerCube(float3 _p)
    {
        float d = DistanceFromBox(_p,make_float3(1.0));
        
        float cube = DistanceFromBox((_p-0.65f) * 2.86f,make_float3(1.0))/2.86f;

        float s = 1.0;
        for( int m=0; m<6; m++ )
        {
           float3 a = fmodf( _p*s, 2.0 )-1.0;
           s *= 3.0;
           float3 r = fabsf(1.0 - 3.0 * fabsf(a));
           
           float c = DistanceFromCross(r)/s;
           d = max(cube,max(d,c));
        } 

        return d;
    }

}
#endif  /* !SDF_H_ */