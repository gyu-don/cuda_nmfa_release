// Copyright 2018 D-Wave Systems Inc.
// Author: William Bernoudy (wbernoudy@dwavesys.com)

#include <vector>
#include <iostream>
#include <algorithm>
#include <stdexcept>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime_api.h>
#include <cuda.h>

#include "cuda_nmfa.h"

#define cudaErrorCheck(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess)
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

// Algorithm "xorwow" from p. 5 of Marsaglia, "Xorshift RNGs"
// NOTE: rng_state vars must be initialized and be type uint32_t
// let rng_state5 be t
#define XORWOW(rand) do {                       \
    rng_state5 = rng_state3;                    \
    rng_state5 ^= rng_state5 >> 2;              \
    rng_state5 ^= rng_state5 << 1;              \
    rng_state3 = rng_state2;                    \
    rng_state2 = rng_state1;                    \
    rng_state1 = rng_state0;                    \
    rng_state5 ^= rng_state0;                   \
    rng_state5 ^= rng_state0 << 4;              \
    rng_state0 = rng_state5;                    \
    rand = rng_state5 + (rng_state4 += 362437); \
} while (0)

// Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs"
#define XORSHIFT32_(rand) do { \
	rand ^= rand << 13;        \
	rand ^= rand >> 17;        \
	rand ^= rand << 5;         \
} while (0)

using namespace std;

constexpr uint32_t rng_max = (uint32_t)-1;
constexpr float rng_max_div_two_pi = 683565275.4172766;

__global__ void 
__launch_bounds__(__N__, 1)
gpu_nmfa_kernel(float* global_J, int* samples, 
        float* betas, int num_stages,
        float noise, float recombination,
        uint32_t seed) {
    extern __shared__ float shm_states[];

    seed += blockDim.x*blockIdx.x + threadIdx.x;

    uint32_t rng_state0, rng_state1, rng_state2, 
             rng_state3, rng_state4, rng_state5; 

    START_PYTHON_PREPROCESS
    for @i from 0 to 4
    XORSHIFT32_(seed);
    rng_state@i = seed;
    endfor
    END_PYTHON_PREPROCESS

    rng_state4 = 0; // still need to initialize this part of the rng state
                      // or it gets competely optimized out and rng doesn't
                      // doesn't work at all

    uint32_t rand0, rand1;

    float current_st = 0;
    shm_states[threadIdx.x] = current_st;

    float mf_normalizer = 0.0;

    // load J into registers
    START_PYTHON_PREPROCESS
    for @i from 0 to __N__
        float J@i = global_J[@i + threadIdx.x*__N__];
        mf_normalizer += fabsf(J@i);
    endfor
    END_PYTHON_PREPROCESS

    mf_normalizer = -1.0/sqrt(mf_normalizer);

    float previous_contribution = 1.0 - recombination;

    __syncthreads();

    for (int stage_idx = 0; stage_idx < num_stages; stage_idx++) {
        float beta = betas[stage_idx];

        // generate two Gaussian samples using the Box-Muller transform
        XORWOW(rand0);
        XORWOW(rand1);

        float R = sqrt(-2.0*__logf((float)rand0 / rng_max)) * noise;
        float theta = (float)rand1 / rng_max_div_two_pi;
        float Z0 = __sinf(theta)*R;
        float Z1 = __cosf(theta)*R;

        // do two sweeps, once with each Gaussian sample
        float noise_sample = Z0;

        #pragma unroll
        for (int i = 0; i < 2; i++) {

            float mf = 0;
            START_PYTHON_PREPROCESS
            for @i from 0 to __N__
                mf += shm_states[@i] * J@i;
            endfor
            END_PYTHON_PREPROCESS

            mf *= mf_normalizer;
            mf += noise_sample;
            
            // mean field update
            current_st = previous_contribution*current_st + recombination*tanhf(mf*beta);

            shm_states[threadIdx.x] = current_st;

            // for the next round, use the next gaussian sample
            noise_sample = Z1;
        }
        __syncthreads();
    }

    // write out the state
    samples[blockIdx.x*__N__ + threadIdx.x] = current_st > 0 ? 1 : -1;
}

float gpu_nmfa(const int N, float* J,
        vector<float> betas,
        int num_samples, int* samples, 
        float noise, float recombination,
        uint32_t seed) {

    if (N != __N__)
        throw std::invalid_argument("passed in N is not the size the kernel was compiled for (__N__)");

    float* d_J;
    float* d_betas;

    cudaErrorCheck(cudaMalloc(&d_J, N*N * sizeof(float)));
    cudaErrorCheck(cudaMemcpy(d_J, J, N*N * sizeof(float), cudaMemcpyHostToDevice));

    // allocate for betas and copy to device
    cudaErrorCheck(cudaMalloc(&d_betas, betas.size() * sizeof(float)));
    cudaErrorCheck(cudaMemcpy(d_betas, &betas[0], betas.size() * sizeof(float), cudaMemcpyHostToDevice));

    const int num_blocks = num_samples;
    const int shm_bytes = N*sizeof(float);
    const int block_size = N;

    float* d_energies;
    cudaErrorCheck(cudaMalloc(&d_energies, num_samples*sizeof(float)));

    // the kernel will output the resulting state to this sample array
    int* d_samples;
    cudaErrorCheck(cudaMalloc(&d_samples, num_samples*N*sizeof(int)));

    cudaErrorCheck(cudaPeekAtLastError());

    cudaEvent_t start, stop;
    float elapsedTime;

    cudaEventCreate(&start);
    cudaEventRecord(start, 0);

    gpu_nmfa_kernel<<<num_blocks, block_size, shm_bytes>>>(d_J,
                                                   d_samples,
                                                   d_betas, betas.size(),
                                                   noise, recombination,
                                                   seed);
    cudaErrorCheck(cudaPeekAtLastError());

    cudaEventCreate(&stop);
    cudaEventRecord(stop,0);
    cudaEventSynchronize(stop);

    cudaErrorCheck(cudaMemcpy(samples, d_samples, num_samples*N*sizeof(int), cudaMemcpyDeviceToHost));

    cudaEventElapsedTime(&elapsedTime, start,stop);

    cudaErrorCheck(cudaFree(d_J));
    cudaErrorCheck(cudaFree(d_betas));
    cudaErrorCheck(cudaFree(d_energies));
    cudaErrorCheck(cudaFree(d_samples));

    return elapsedTime;
}
