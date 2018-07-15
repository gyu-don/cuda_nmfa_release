// Copyright 2018 D-Wave Systems Inc.
// Author: William Bernoudy (wbernoudy@dwavesys.com)

#include <vector>
#include <cstdint>

#ifndef CUDA_NMFA_H
#define CUDA_NMFA_H

float gpu_nmfa(int N, float* J,
        std::vector<float> betas,
        int num_samples, int* samples, 
        float noise, float recombination,
        uint32_t seed);

#endif // CUDA_NMFA_H
