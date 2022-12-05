#include "raymarching.cuh"

#include <math.h>

#include "Settings.cuh"
#include"SignedDistanceFunctions.cuh"

#pragma region Utils

// get sign function
#define sign(x) ((x > 0) - (x < 0))
// clamp macro
#define clamp(x, a, b) (x < a ? a : (x > b ? b : x))

__device__
inline float rm::SmoothMin(float dstA, float dstB, float k) {
    float h = std::fmaxf(k - abs(dstA - dstB), 0) / k;
    return std::fminf(dstA, dstB) - h * h * h * k * (1.0f / 6.0f);
}

#pragma endregion

__device__
float rm::RayMarching::MapTheWorld(float3 _p)
{
    float sphere_0 = DistanceFromSphere(_p, make_float3(0.0f,0.0f,2.0f), 0.5f);
    float sphere_1 = DistanceFromSphere(_p, make_float3(-0.5f,0.75f,2.0f), 0.5f);
    
    float plane_0 = DistanceFromPlane(_p, -0.25f);

    // return min union
    return SmoothMin(SmoothMin(sphere_0, sphere_1, 0.5), plane_0, 1.0);
}

// function to apply Beer-Lambert law to diffuse intensityi
__device__
float3 rm::RayMarching::ApplyBeerLambert(float3 color, float distanceTraveled, float absorptionCoefficient)
{
    // calculate light absorption using Beer-Lambert law
    float absorption = exp(-absorptionCoefficient * distanceTraveled);
    
    return color * absorption + FOG_COLOR * (1 - absorption);
}

__device__
float3 rm::RayMarching::CalculateNormal(float3 _p)
{
    return normalize(make_float3(
        MapTheWorld(make_float3(_p.x + EPSILON, _p.y, _p.z)) - MapTheWorld(make_float3(_p.x - EPSILON, _p.y, _p.z)),
        MapTheWorld(make_float3(_p.x, _p.y + EPSILON, _p.z)) - MapTheWorld(make_float3(_p.x, _p.y - EPSILON, _p.z)),
        MapTheWorld(make_float3(_p.x, _p.y, _p.z + EPSILON)) - MapTheWorld(make_float3(_p.x, _p.y, _p.z - EPSILON))
    ));
    
    const float3 epsilon = make_float3(EPSILON, 0.0f, 0.0f);
    
    float3 epsilon_xyy = make_float3(epsilon.x, epsilon.y, epsilon.y);
    float3 epsilon_yxy = make_float3(epsilon.y, epsilon.x, epsilon.y);
    float3 epsilon_yyx = make_float3(epsilon.y, epsilon.y, epsilon.x);
    float d0 = MapTheWorld(_p);

    float3 d1 = make_float3(
        MapTheWorld(_p - epsilon_xyy),
        MapTheWorld(_p - epsilon_yxy),
        MapTheWorld(_p - epsilon_yyx)
    );

    float3 normal = normalize(d0 - d1);

    return normalize(normal);
}

__device__
float3 rm::RayMarching::Raymarch(float3 ro, float3 rd)
{
    float3 currentPosition = ro;
    float distanceTraveled = 0.0f;
    float distanceToClosest = 0.0f;

    for (int i = 0; i < NUMBER_OF_STEPS; ++i)
    {
        // Calculate our current position along the ray
        currentPosition = ro + rd * distanceTraveled;

        // get distance to world geometry
        distanceToClosest = MapTheWorld(currentPosition);

        // accumulate the distance traveled thus far
        distanceTraveled += distanceToClosest;
        
        if (distanceToClosest < MINIMUM_HIT_DISTANCE) // hit
        {
            //print distance
            //break;
            
            // We hit something! Return red for now
            float3 normal = CalculateNormal(currentPosition);

            //return normal * 0.5 + 0.5;

            // For now, hard-code the light's position in our scene
            float3 lightPosition = make_float3(2.0, -5.0, 3.0);

            // Calculate the unit direction vector that points from
            // the point of intersection to the light source
            float3 directionToLight = normalize(currentPosition - lightPosition);

            float diffuseIntensity = max(0.0, dot(normal, directionToLight));

            //diffuseIntensity = //ApplyBeerLambert(diffuseIntensity, distanceTraveled, 1.5);
            float3 finalColor =  make_float3(1.0, 0.0, 0.0) * diffuseIntensity;

            finalColor = ApplyBeerLambert(finalColor, distanceTraveled, FOG_THICKNESS);
            
            return finalColor;
        }

        if (distanceTraveled > MAXIMUM_TRACE_DISTANCE) // miss
        {
            break;
        }
    }

    // If we get here, we didn't hit anything so just
    // return a background color
    return ApplyBeerLambert(make_float3(1), distanceTraveled, FOG_THICKNESS);
    //return make_float3(distanceTraveled/5);
    //return make_float3(0.390625f, 0.58203125f, 0.92578125f);
}

void rm::RayMarching::Init(sf::RenderWindow* _window)
{ 
    cam.pos = make_float3(0.0f, 0.0f, 0.0f);
    cam.dir = make_float3(0.0f, 0.0f, 1.0f);
	cam.right = normalize(cross(cam.dir, make_float3(0, 1, 0)));
	cam.up = normalize(cross(cam.right, cam.dir));
	float fov = FOV / 180.0f * float(M_PI);
	cam.invhalffov = 1.0f / std::tan(fov / 2.0f);

    //_window->setMouseCursorVisible(false);
    //_window->setMouseCursorGrabbed(true);
}

void rm::RayMarching::Update(sf::RenderWindow* _window, float _dt)
{
    /*
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::W))
    {
        cam.pos += CAM_SPEED * _dt * cam.dir;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::S))
    {
        cam.pos -= CAM_SPEED * _dt * cam.dir;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::A))
    {
        cam.pos -= CAM_SPEED * _dt * cam.right;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::D))
    {
        cam.pos += CAM_SPEED * _dt * cam.right;
    }
    */
    
}

__device__ 
float3 rm::RayMarching::Render(int _pX, int _pY)
{
    float2 resolution = make_float2((float)ImageWidth, (float)ImageHeight);   //screen resolution
	float2 coordinates = make_float2((float)_pX, (float)_pY);   //fragment coordinates
    
    //float2 uv = ( 2 * coordinates - resolution) / resolution.y;
    float2 uv = ( coordinates - (resolution * 0.5)) / resolution.y;
	
    float3 ro = make_float3(0.0f);   //ray origin
    float3 rd = normalize(make_float3(uv, 1.0f) - ro);   //ray direction
    
    float3 shaded_color = Raymarch(ro, rd);
    //float3 shaded_color = make_float3(uv.x, uv.y, 0.0f);

    return shaded_color;
}

void rm::RayMarching::Shutdown()
{
    
}
