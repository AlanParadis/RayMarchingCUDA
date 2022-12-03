#ifndef CUDAHELPER_H_
#define CUDAHELPER_H_

// get math defines
#define _USE_MATH_DEFINES

// include windows header for compiler link
#include <windows.h>

// For the CUDA runtime routines (prefixed with "cuda_")
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <curand.h>
#include <cuda_gl_interop.h>
// Vector operation library
#include "vectorOps.cuh"

#include <iostream>

#ifdef __INTELLISENSE__
#define CUDA_KERNEL(...)
#else
#define CUDA_KERNEL(...) <<< __VA_ARGS__ >>>
#endif

#pragma region CudaErrorHandling
// from : https://github.com/rogerallen/raytracinginoneweekendincuda/blob/ch01_output_cuda/main.cu
// limited version of checkCudaErrors from helper_cuda.h in CUDA examples
#define checkCudaErrors(val) check_cuda( (val), #val, __FILE__, __LINE__ )

static inline void check_cuda(cudaError_t result, char const* const func, const char* const file, int const line) {
    if (result) {
        std::cerr << "CUDA error = " << static_cast<unsigned int>(result) << " at " <<
            file << ":" << line << " '" << func << "' \n";
        // Make sure we call CUDA Device Reset before exiting
        cudaDeviceReset();
        exit(99);
    }
}
#pragma endregion CudaErrorHandling

#endif  /* !CUDAHELPER_H_ */