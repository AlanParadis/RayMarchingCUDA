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
        for (int i = 0; i < 7; i++)
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

    // params:
    // p: arbitrary point in 3D space
    // returns: the distance between the point and a tetrahedron
    __device__
    float DistanceFromTetrahedron(float3 _p)
    {        
        return (max(
	        abs(_p.x + _p.y) - _p.z,
	        abs(_p.x - _p.y) + _p.z) - 1.0) / sqrt(3.);
    }

    // Fold a point across a plane defined by a point and a normal
    // The normal should face the side to be reflected
    __device__
    float3 SierpinskiFold(float3 point, float3 pointOnPlane, float3 planeNormal)
    {
        // Center plane on origin for distance calculation
        float distToPlane = dot(point - pointOnPlane, planeNormal);
        
        // We only want to reflect if the dist is negative
        distToPlane = min(distToPlane, 0.0);
        return point - 2.0 * distToPlane * planeNormal;
    }

    __device__
    float DistanceFromSierpinski(float3 p)
    {
        // Vertices of the tetrahedron defined by the SDF
        const float3 vertices[4] = {
            float3{ 1.0, 1.0, 1.0 },
            float3{ -1.0, 1.0, -1.0 },
            float3{ -1.0, -1.0, 1.0 },
            float3{ 1.0, -1.0, -1.0 } };
        
        float scale = 1.0f;
        for (int i = 0; i < 9; i++)
        {
            // Scale point toward corner vertex, update scale accumulator
            p -= vertices[0];
            p *= 2.0;
            p += vertices[0];
            
            scale *= 2.0;
            
            // Fold point across each plane
            for (int i = 1; i <= 3; i++)
            {
                // The plane is defined by:
                // Point on plane: The vertex that we are reflecting across
                // Plane normal: The direction from said vertex to the corner vertex
                float3 normal = normalize(vertices[0] - vertices[i]); 
                p = SierpinskiFold(p, vertices[i], normal);
            }
        }
        // Now that the space has been distorted by the IFS,
        // just return the distance to a tetrahedron
        // Divide by scale accumulator to correct the distance field
        return DistanceFromTetrahedron(p) / scale;
    }

#pragma region Romanesco Broccoli 

    // remap a 2D rounded cone to a circle
    __device__
    float2 remap(float2 p) {
        const float CONE_THETA = 0.7; // angle of the cone, in radians
        const float CONE_RADIUS = 0.3; // radius of the rounded edge of the cone
        const float CONE_LBOT = (PI*0.5+CONE_THETA); // length of the bottom part of the cone
        const float CONE_LFLAT = ((tan(PI*0.5-CONE_THETA))*(1.0-CONE_RADIUS)); // length of the flat part of the cone
        const float CONE_LTOP = ((PI*0.5-CONE_THETA)*CONE_RADIUS); // length of the top part of the cone
        const float CONE_L = (CONE_LBOT+CONE_LFLAT+CONE_LTOP); // total length of the cone
        const float2 CONE_SLOPE = make_float2(cos(CONE_THETA), sin(CONE_THETA)); // slope of the flat part of the cone
        const float2 CONE_CSLOPE = (make_float2(CONE_SLOPE.y, CONE_SLOPE.x) * make_float2(-1, 1)); // slope of the bottom part of the cone
        const float CONE_HEIGHT = length(make_float2(1.0-CONE_RADIUS, CONE_LFLAT)); // height of the cone

        // flip coordinates so they're easier to work with
        // we'll flip them back before returning it
        float sign = p.x > 0.0 ? +1.0 : -1.0;
        p.x = abs(p.x);
        // go to polar coordinates
        float theta = 0.0;
        float radius = 0.0;
        // do the bottom part
        float bottomPos = atan2(p.x, -p.y) / (PI * 0.5 + CONE_THETA);
        if (bottomPos < 1.0) {
            theta = (bottomPos * CONE_LBOT) / CONE_L;
            radius = length(p);
        }
        else {
            // do the flat part
            float pos = dot(p, CONE_CSLOPE);
            float flatPos = pos / CONE_LFLAT;
            if (flatPos < 1.0) {
                theta = (CONE_LBOT + flatPos * CONE_LFLAT) / CONE_L;
                radius = dot(p, CONE_SLOPE);
            }
            else {
                // do the top part
                p.y -= CONE_HEIGHT;
                float topPos = (atan2(p.y, p.x) - CONE_THETA) / (PI * 0.5 - CONE_THETA);
                theta = (CONE_LBOT + CONE_LFLAT + topPos * CONE_LTOP) / CONE_L;
                radius = length(p) + (1.0 - CONE_RADIUS);
            }
        }
        // squeeze the angle toward the top of the broccoli
        theta *= theta;
        // go back to cartesian, flip the sign and return
        theta = theta * sign * PI;
        return make_float2(sin(theta), -cos(theta)) * radius;
    }

    // deform a 3D sphere to match a cone
    __device__
    float3 deform( float3 p)
    {
        // Convert input point to cylindrical coordinates
        float2 direction = make_float2(p.x, p.y);
        float directionLength = length(direction);
        float2 cylindrical = make_float2(directionLength, -p.z);
        // Remap a circle to a rounded cone
        cylindrical = remap(cylindrical);
        // Convert back to 3D coordinates
        return make_float3(direction/directionLength*cylindrical.x, cylindrical.y);
    }

    // Keinert et al's inverse Spherical Fibonacci Mapping code
    // https://www.shadertoy.com/view/lllXz4
    __device__
    float3 inverseSF( float3 p, const float n ) 
    {
        float m = 1.0-1.0/n;
        float phi = min(atan2(p.y,p.x),PI);
        float k = max(2.,std::floor(log(n*PI*sqrt(5.)*(1.-p.z*p.z))/log(PHI+1.)));
        float Fk = pow(PHI,k)/sqrt(5.0);
        float2 F = make_float2(round(Fk),round(Fk*PHI));
        float2 ka = 2.0*F/n;
        float2 kb = 2.0*PI*(fract((F+1.0)*PHI)-(PHI-1.0)); 

        float determinant = ka.y*kb.x - ka.x*kb.y;
        float invDet = 1.0f / determinant;

        float2 iB_col1 = make_float2(ka.y, -ka.x) * invDet;
        float2 iB_col2 = make_float2(kb.y, -kb.x) * invDet;

        float2 c = floor(make_float2(iB_col1.x*phi + iB_col2.x*(p.z-m), iB_col1.y*phi + iB_col2.y*(p.z-m)));
 
        float d = 8.0;
        float3 res = make_float3(0);
        for(int s = 0 ; s < 4 ; s++) {
            float2 uv = make_float2(float(s-2*(s/2)),float(s/2));
            float i = dot(F,uv+c);
            float phi = 2.0*PI*fract(i*PHI);
            float cT = m-2.0*i/n;
            float sT = sqrt(1.0-cT*cT);
            float3 q = make_float3(cos(phi)*sT, sin(phi)*sT,cT);
            float sqDist = dot(q-p,q-p);
            if (sqDist < d) {
                d = sqDist;
                res = q;
            }
        }
        return res;
    }

    __device__
    float RomanescoBrocoli(float3 p) 
    {
        // parameters of the fractal formula
        // FRACTAL_LEVELS controls the number of iterations the fractal formula will go through
        const float FRACTAL_LEVELS = 2.0f;
        // FIBO_COUNT controls the number of Fibonacci points used to generate the fractal shape
        const float FIBO_COUNT = 150.0f;
        // flip the z-axis to create a mirror image of the shape
        p.z = -p.z;
        // deform the point using a user-defined function
        p = deform(p);
        // initialize a variable to keep track of the cumulative scale factor
        float cumulativeScale = 1.0;
        // calculate the initial distance from the point to the surface of the fractal
        float distanceFromSurface = length(p) - 1.0;
        for (int i = 0; i < FRACTAL_LEVELS; i++) {
            // calculate the height of the point on the fractal surface
            float heightFactor = smoothstep(-1.0, 1.5, p.z);
            // calculate the nearest Fibonacci point on the fractal surface
            float3 nearestFibonacciPoint = inverseSF(normalize(p), FIBO_COUNT);
            // move the point to the nearest Fibonacci point
            p -= nearestFibonacciPoint;
            // re-orient the point to aim towards the normal of the surface at the nearest Fibonacci point
            float3 tangent = normalize(cross(nearestFibonacciPoint, make_float3(0, 0, 1)));
            float3 crossTangent = cross(nearestFibonacciPoint, tangent);
            p = make_float3(dot(p, tangent), dot(p, crossTangent), -dot(p, nearestFibonacciPoint));
            // change the scale of the point based on its height on the fractal surface
            float scaleFactor = mix(3.0, 7.0, heightFactor);
            p *= scaleFactor;
            // adjust the x and y coordinates of the point based on its height on the fractal surface
            p.x *= mix(1.5, 1.0, heightFactor);
            p.y *= mix(1.5, 1.0, heightFactor);
            // deform the point again using the user-defined function
            p = deform(p);
            // update the cumulative scale factor
            cumulativeScale *= scaleFactor;
            // calculate the new distance from the point to the surface of the fractal
            float newDistanceFromSurface = (length(p) - 1.0) / cumulativeScale;
            // use the SmoothMin function to blend the new distance with the previous distance
            distanceFromSurface = SmoothMin(distanceFromSurface, newDistanceFromSurface, 0.1);
        }
        return distanceFromSurface;
    }

#pragma endregion


}
#endif  /* !SDF_H_ */