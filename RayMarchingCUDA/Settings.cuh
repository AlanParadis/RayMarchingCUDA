#ifndef SETTINGS_H_
#define SETTINGS_H_

#define ScreenWidth 1224
#define ScreenHeight 968

#define ImageWidth ScreenWidth/2
#define ImageHeight ScreenHeight/2

#define NB_THREAD 153

#define EPSILON 0.00001f

#define MOUSE_SENSITIVITY 0.01f;

// Camera settings
#define CAM_SPEED 1.5f
#define CAM_SENSITIVITY 0.001f
#define FOV 120.0f

#define NUMBER_OF_STEPS 320
#define MINIMUM_HIT_DISTANCE 0.0001f
#define MAXIMUM_TRACE_DISTANCE 10


#define FOG_COLOR make_float3(0.39f, 0.58f, 0.92f)
#define FOG_THICKNESS 0.250f

//lime green glow color
#define GLOW_COLOR make_float3(0.0f, 1.0f, 0.25f)
#define GLOW_INTENSITY 0.1f
#define GLOW_THICKNESS 5.5f

#define AMBIENT_OCCLUSION_SAMPLES 10

#define LIGHT_DIRECTION make_float3(-0.36f, 0.48f, 0.80f)
#define LIGHT_COLOR make_float3(1.0f, 0.9f, 0.6f)

#define SHADOW_DARKNESS 0.95f
#define SHADOW_SHARPNESS 16.0f
#define SPECULAR_HIGHLIGHT 100.0f

#define SUN_SHARPNESS 1.0f
#define SUN_SIZE 0.0005f

#define AMBIENT_OCCLUSION_STRENGTH 0.001f
#define AMBIENT_OCCLUSION_COLOR_DELTA make_float3(0.8f, 0.8f, 0.8f)

#endif  /* !SETTINGS_H_ */