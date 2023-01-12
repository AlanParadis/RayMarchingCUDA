#include "raymarching.cuh"

#include <math.h>

#include "Settings.cuh"
#include"SignedDistanceFunctions.cuh"
#include "Utils.cuh"

using namespace rm;

#pragma region Utils

__device__ __host__
inline float3 rm::RotatePoint(float3 point, mat3 rotation, float3 origin)
{
    return rotation * (point - origin) + origin;
}

#pragma endregion

// Signed Distance Function for the world
__device__
float RayMarching::MapTheWorld(float3 _p)
{
    // create 2 mandelbuld next to each other by 1 unit and rotate them
    float3 p1 = RotatePoint(_p, mat3::rotateY(-time), make_float3(0.0f, 0.0f, 0.0f));
    float3 p2 = RotatePoint(_p + make_float3(1.0f,0.0f,0.0f), mat3::rotateY(time), make_float3(0.0f, 0.0f, 0.0f));
    return SmoothMin(Mandelbulb(p1), Mandelbulb(p2), 0.01f);

    return MengerCube(_p);
    
    float3 sphere_0Pos = make_float3(0.0f, 0.0f, 2.0f);
    float sphere_0 = DistanceFromSphere(_p, sphere_0Pos, 0.5f);
    //float sphere_1 = DistanceFromSphere(_p, make_float3(-0.5f,0.75f,2.0f), 0.5f);

    float3 pos = rm::RotatePoint(make_float3(-0.5f, 0.4f, 2.0f), mat3::rotateY(time), sphere_0Pos);
    float sphere_1 = DistanceFromSphere(_p, pos, 0.2f);
    
    pos = rm::RotatePoint(make_float3(-0.5f, 0.6f, 2.0f), mat3::rotateY(time*2.0f), sphere_0Pos);
    float sphere_2 = DistanceFromSphere(_p, pos, 0.2f);
    
    float plane_0 = DistanceFromPlane(_p, -0.25f);

    // return min union
    return SmoothMin(SmoothMin(SmoothMin(sphere_0, sphere_1, 0.25f), sphere_2, 0.5f),plane_0, 1.0f);
}

// Apply Beer-Lambert law to generate distance based fog
__device__
float3 RayMarching::ApplyBeerLambert(float3 color, float distanceTraveled, float absorptionCoefficient)
{
    // calculate light absorption using Beer-Lambert law
    float absorption = exp(-absorptionCoefficient * distanceTraveled);
    
    return color * absorption + FOG_COLOR * (1.f - absorption);
}

__device__
float3 RayMarching::gradient(float t)
{
    float3 red = make_float3(1.f, 0.f, 0.f);
    float3 green = make_float3(0.f, 1.f, 0.f);
    float3 blue = make_float3(0.f, 0.f, 1.f);

    if (t < 1.0f / 3.0f)
    {
        // Interpolate from red to green
        return lerp(red, green, t * 3.0f);
    }
    else if (t < 2.0f / 3.0f)
    {
        // Interpolate from green to blue
        return lerp(green, blue, (t - 1.0f / 3.0f) * 3.0f);
    }
    else
    {
        // Interpolate from blue to red
        return lerp(blue, red, (t - 2.0f / 3.0f) * 3.0f);
    }
}

__device__
float3 RayMarching::ColorFromOrbitTrap(float3 currentPosition, float3 orbitTrap)
{
    // Calculate the distance from the current position to the orbit trap
    float distance = length(currentPosition - orbitTrap);

    // Use the distance to generate a color value
    // Calculate the blend factor between the current color and the next color
    float blendFactor = (1.0f + sin((distance) * 3.1415f)) / 2.0f;
    
    // Blend between the current color and the next color
    return gradient(blendFactor);
}

// from: https://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#surface-normals-and-lighting
__device__
float3 RayMarching::CalculateNormal(float3 _p)
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
float3 RayMarching::Raymarch(float3 ro, float3 rd)
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
            // We hit something! Return red for now
            float3 normal = CalculateNormal(currentPosition);
            // For now, hard-code the light's position in our scene
            float3 lightPosition = make_float3(2.0f, -5.0f, 3.0f);
            // Calculate the unit direction vector that points from
            // the point of intersection to the light source
            float3 directionToLight = normalize(currentPosition - lightPosition);
            // Calculate the diffuse intensity
            float diffuseIntensity = max(0.0f, dot(normal, directionToLight));
            // Calculate the color of the object
            float3 baseColor = ColorFromOrbitTrap(currentPosition, make_float3(0));
            // Apply light to red colored scene
            float3 finalColor =  baseColor * diffuseIntensity;
            // Generate distance fog with Beer Lambert law
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
    return ApplyBeerLambert(make_float3(1.0f), distanceTraveled, FOG_THICKNESS);
}

void RayMarching::Init(sf::RenderWindow* _window)
{ 
    // camera setup
    camera.pos = make_float3(0.0f, 0.0f, 0.0f);
    camera.dir = make_float3(1.0f, 0.0f, 0.0f);
	camera.right = normalize(cross(camera.dir, make_float3(0, 1, 0)));
	camera.up = normalize(cross(camera.right, camera.dir));
	float fov = FOV / 180.0f * float(M_PI);
	camera.invhalffov = 1.0f / std::tan(fov / 2.0f);
    // grab mouse
    _window->setMouseCursorVisible(false);
    _window->setMouseCursorGrabbed(true);
    isMouseLock = true;
    // set mouse to center
    sf::Vector2i center(_window->getSize().x / 2, _window->getSize().y / 2);
    sf::Mouse::setPosition(center, *_window);

    time = 0;
}

void RayMarching::Event(sf::RenderWindow* _window, sf::Event* _evt)
{
    // middle click to toggle mouse lock
    if (_evt->type == sf::Event::MouseButtonPressed && _evt->mouseButton.button == sf::Mouse::Middle)
    {
        if (isMouseLock)
        {
            _window->setMouseCursorVisible(true);
            _window->setMouseCursorGrabbed(false);
            isMouseLock = false;
        }
        else
        {
            _window->setMouseCursorVisible(false);
            _window->setMouseCursorGrabbed(true);
            isMouseLock = true;
        }
    }
}

void RayMarching::Update(sf::RenderWindow* _window, float _dt)
{
    time += _dt;
    
    //! KEYBOARDS INPUTS
    
    // Handle user input to move the camera
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::W))
    {
        // Move camera forward
        camera.pos += camera.dir * CAM_SPEED * _dt;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::S))
    {
        // Move camera backward
        camera.pos -= camera.dir * CAM_SPEED * _dt;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::A))
    {
        // Move camera left
        camera.pos -= camera.right * CAM_SPEED * _dt;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::D))
    {
        // Move camera right
        camera.pos += camera.right * CAM_SPEED * _dt;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::E))
    {
        // Move camera up
        camera.pos += camera.up * CAM_SPEED * _dt;
    }
    if (sf::Keyboard::isKeyPressed(sf::Keyboard::Q))
    {
        // Move camera down
        camera.pos -= camera.up * CAM_SPEED * _dt;
    }

    // no mouse look is mouse is unlocked
    if (!isMouseLock)
        return;
    
    //! MOUSE LOOK

    // Get screen center
    sf::Vector2i center(_window->getSize().x / 2.f, _window->getSize().y / 2.f);
    // get mose delta from screen center
    sf::Vector2i delta = sf::Mouse::getPosition(*_window) - center;
   
    // get rotations
    float pitch = -delta.y * CAM_SENSITIVITY;
    float yaw = delta.x * CAM_SENSITIVITY;
    
    // First, apply the yaw rotation around the camera's up vector
    camera.dir = normalize(camera.dir * cos(yaw) + cross(camera.dir, camera.up) * sin(yaw));
    // Then, apply the pitch rotation around the camera's right vector
    camera.dir = normalize(camera.dir * cos(pitch) + camera.up * sin(pitch));    
    
    // update cam right and up vector
	camera.right = normalize(cross(camera.dir, make_float3(0.f, 1.f, 0.f)));
    camera.up = normalize(cross(camera.right, camera.dir));
    
    // reset mouse in center
    sf::Mouse::setPosition(center, *_window);
}

__device__ 
float3 RayMarching::Render(int _pX, int _pY)
{
    //screen resolution
    float2 resolution = make_float2((float)ImageWidth, (float)ImageHeight);   
	// pixel coordinates
    float2 coordinates = make_float2((float)_pX, (float)_pY);
    // get screen uv
    float2 uv = ( coordinates - (resolution * 0.5f)) / resolution.y;
    // ray origin
    float3 ro = camera.pos;
    // ray direction
    float3 rd = normalize(camera.dir + uv.x * camera.right + uv.y * camera.up + camera.dir * camera.invhalffov);
    // Raymarch to find the shaded color of the fragment
    float3 shaded_color = Raymarch(ro, rd);
    // return color
    return shaded_color;
}

void RayMarching::Shutdown()
{
    
}
