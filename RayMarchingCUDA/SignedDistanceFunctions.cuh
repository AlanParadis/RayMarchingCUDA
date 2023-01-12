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
    // returns: the distance between the point and Menger Sponge
    __device__
    float MengerCube(float3 _p)
    {
        // Initialize distance from standard cube
        float distanceFromStandardCube = DistanceFromBox(_p, make_float3(1.0));

        // Scale point and calculate distance from scaled cube
        float3 scaledPoint = (_p - 0.65f) * 2.86f;
        float distanceFromScaledCube = DistanceFromBox(scaledPoint, make_float3(1.0)) / 2.86f;

        float scalingFactor = 1.0;
        for (int i = 0; i < 10; i++)
        {
            // Calculate point in relation to current iteration's grid
            float3 pointInGrid = fmodf(_p * scalingFactor, 2.0) - 1.0;
            scalingFactor *= 3.0;

            // Calculate distance from cross shape
            float3 distanceFromCrossShape = fabsf(1.0 - 3.0 * fabsf(pointInGrid));
            float distance = DistanceFromCross(distanceFromCrossShape) / scalingFactor;

            // Update distance from Menger cube
            distanceFromStandardCube = max(distanceFromScaledCube, max(distanceFromStandardCube, distance));
        }

        return distanceFromStandardCube;
    }
    
    // params:
    // p: arbitrary point in 3D space
    // returns: the distance between the point and the Mandelbulb
    __device__
    float Mandelbulb(const float3& point) 
    {
        // Set the maximum number of iterations
        const int kMaxIterations = 4;
        // Set the exponent value
        const float kExponent = 3.5f;
        // Set the bailout value
        const float kBailout = 128.0f;
        // Initialize the working point
        float3 workingPoint = point;
        // Get the dot product of the working point
        float dotProduct = dot(workingPoint, workingPoint);
        // Initialize the delta z value
        float deltaZ = 1.0f;

        for (int i = 0; i < kMaxIterations; i++) {
            // Update the delta z value
            deltaZ = 8.0f * pow(dotProduct, kExponent) * deltaZ + 1.0f;

            // Get the distance from the origin
            float distance = length(workingPoint);
            // Get the angle in the y-z plane
            float angleYZ = 8.0f * acos(workingPoint.y / distance);
            // Get the angle in the x-z plane
            float angleXZ = 8.0f * atan2(workingPoint.x, workingPoint.z);
            // Update the working point
            workingPoint = point + pow(distance, 8.0f) * make_float3(sin(angleYZ) * sin(angleXZ), cos(angleYZ), sin(angleYZ) * cos(angleXZ));

            // Update the dot product
            dotProduct = dot(workingPoint, workingPoint);
            // Check if the dot product is greater than the bailout value
            if (dotProduct > kBailout) {
                break;
            }
        }

        // Return the final value
        return 0.25f * log(dotProduct) * sqrt(dotProduct) / deltaZ;
    }


}
#endif  /* !SDF_H_ */