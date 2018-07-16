# CUDA NMFA

## Requirements

You will need CUDA and python installed. `nvcc` and `python` should be in your
path.

## Building

Edit `Makefile` and ensure the `-arch` compiler argument matches the compute
capability of your NVIDIA GPU.

Then simply run

```
$ make
```

By default this will build a version for N=150 (N is problem size).

If you want to compile a version for a different N, run

```
$ make N=100
```

This will create a shared library called `cuda_nmfa.so` at the top directory.

## Usage

The shared library provides a single function with the signature

```cpp
float gpu_nmfa(int N, float* J,
        std::vector<float> betas,
        int num_samples, int* samples, 
        float noise, float recombination,
        uint32_t seed);
```

  * `N`: problem size
  * `J`: pointer to `N*N` length array, where `J[i*N + j]` is the weight on the edge between spins `i` and `j`. Note that `J[i*N + j]` should equal `J[j*N + i]`.
  * `betas`: `std::vector` of betas. Two sweeps will be performed at each beta, making the number of sweeps equal to `2*betas.size()`.
  * `num_samples`: the desired number of output samples
  * `noise`: the amount of noise (sigma)
  * `recombination`: fraction of spin update used to calculate new spin (alpha)
  * `seed`: seed for the RNG

Solver.cpp is wrapper and executable.

Usage: ./solver input-json-file


## Author and Copylight
Authors of these files are Andrew D. King, William Bernoudy, James King, Andrew J. Berkley, Trevor Lanting.
https://arxiv.org/abs/1806.08422v1
These files are licensed in Attribution-NonCommercial-ShareAlike 4.0.

Takumi Kato (@gyu-don) modified and add some files.
See the commit log.
