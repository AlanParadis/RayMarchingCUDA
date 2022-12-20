

//compute_20,sm_20;compute_30,sm_30;compute_35,sm_35;compute_37,sm_37;compute_50,sm_50;compute_52,sm_52
#ifdef NDEBUG
#define MAIN() int CALLBACK WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
#endif
#ifdef _DEBUG
#define MAIN() int main()
#endif

#include <stdio.h>
#include <algorithm>
#include <iterator>
#include <set>
#include <string>

#include <GL/glew.h>
#include <GL/wglew.h>
#include <GL/freeglut.h>
#include <SFML/System.hpp>
#include <SFML/Window.hpp>
#include <SFML/Graphics.hpp>

// CUDA
#include "CUDAHelper.cuh"

#include "Settings.cuh"

#include "raymarching.cuh"

__global__ void Cuda2D(float3 *nvTabPixel, rm::RayMarching* rm)
{
	//déterminer l'emplacement où l'on se trouve
	int pixelX = (threadIdx.x + blockIdx.x * blockDim.x);
	int pixelY = (threadIdx.y + blockIdx.y * blockDim.y);

	//Écriture du pixel
	int index = pixelX + pixelY * ImageWidth;
	//nvTabPixel[index] = make_float3(0.390625f, 0.58203125f, 0.92578125f);
	
	nvTabPixel[index] = rm->Render(pixelX, pixelY);
}

MAIN()
{
	float3* nvTabPixel;
	checkCudaErrors(cudaMalloc(&nvTabPixel, ImageWidth*ImageHeight * sizeof(float3)));
	if (nvTabPixel == NULL)
	{
		fprintf(stderr, "Failed to allocate host vectors!\n");
		exit(EXIT_FAILURE);
	}

	GLuint gltexture;
	GLuint pbo;
	cudaGraphicsResource_t cudaPBO;

	sf::RenderWindow window(sf::VideoMode(ScreenWidth, ScreenHeight), "CUDA Ray Marching", sf::Style::Titlebar | sf::Style::Close);
	window.resetGLStates();
	window.setFramerateLimit(0);
	window.setVerticalSyncEnabled(false);

	glewInit();

	glViewport(0, 0, ScreenWidth, ScreenHeight);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0.0, ScreenWidth, ScreenHeight, 0.0, -1.0, 1.0);
	glEnable(GL_TEXTURE_2D);
	glDisable(GL_LIGHTING);
	glDisable(GL_DEPTH_TEST);

	// Unbind any textures from previous.
	glBindTexture(GL_TEXTURE_2D, 0);
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, 0);

	// Create new textures.
	glGenTextures(1, &gltexture);
	glBindTexture(GL_TEXTURE_2D, gltexture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	// Create image
	//https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glTexImage2D.xhtml
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, ImageWidth, ImageHeight, 0, GL_RGB, GL_FLOAT, 0);

	// Create pixel buffer boject.
	glGenBuffers(1, &pbo);
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, pbo);
	glBufferData(GL_PIXEL_UNPACK_BUFFER_ARB, ImageWidth* ImageHeight * sizeof(float3), 0, GL_STREAM_COPY);
	checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cudaPBO, pbo, cudaGraphicsMapFlagsNone));
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, 0);
	glBindTexture(GL_TEXTURE_2D, 0);


	dim3 blockSize(NB_THREAD, 1, 1);
	dim3 gridSize(ImageWidth / (blockSize.x), (ImageHeight / blockSize.y));
	int sharedMemSize = blockSize.x * sizeof(int);
    

	rm::RayMarching* raymarching;

	checkCudaErrors(cudaMallocManaged(&raymarching, sizeof(rm::RayMarching)));

	if (raymarching == nullptr)
	{
		std::cerr << "Cannot allocate memory for the ray marching engine" << std::endl;
		return -1;
	}

    raymarching->Init(&window);
    
	sf::Clock deltaClock;
	int compteur = 0;

	while (window.isOpen())
	{
		sf::Event event;
		while (window.pollEvent(event))
		{
			if (event.type == sf::Event::Closed)
			{
				exit(0);
			}
			if (event.type == sf::Event::KeyPressed)
			{
				if (event.key.code == sf::Keyboard::Escape) exit(0);
			}
            raymarching->Event(&window, &event);
		}
        
		raymarching->Update(&window, deltaClock.restart().asSeconds());

		checkCudaErrors(cudaGraphicsMapResources(1, &cudaPBO, 0));
		size_t numBytes;
		checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void**)&nvTabPixel, &numBytes, cudaPBO));

		//Cuda2D <<< gridSize, blockSize, sharedMemSize >>> (nvTabPixel);
		Cuda2D CUDA_KERNEL(gridSize, blockSize, sharedMemSize)(nvTabPixel, raymarching);
        
		checkCudaErrors(cudaDeviceSynchronize());

		checkCudaErrors(cudaGraphicsUnmapResources(1, &cudaPBO, 0));


		glColor3f(1.0f, 1.0f, 1.0f);

		glBindTexture(GL_TEXTURE_2D, gltexture);
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, pbo);
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ImageWidth, ImageHeight, GL_RGB, GL_FLOAT, 0);

		glBegin(GL_QUADS);
		glTexCoord2f(0.0f, 0.0f);
		glVertex2f(0.0f, float(ScreenHeight));
		glTexCoord2f(1.0f, 0.0f);
		glVertex2f(float(ScreenWidth), float(ScreenHeight));
		glTexCoord2f(1.0f, 1.0f);
		glVertex2f(float(ScreenWidth), 0.0f);
		glTexCoord2f(0.0f, 1.0f);
		glVertex2f(0.0f, 0.0f);
		glEnd();

		glFlush();

		// Release
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, 0);
		glBindTexture(GL_TEXTURE_2D, 0);

		window.display();
		//	exit(0);
	}

	raymarching->Shutdown();

	cudaFree(raymarching);

	return 0;
}

