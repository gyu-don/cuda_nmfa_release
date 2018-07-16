NVCC=nvcc
CUDA_FLAGS=-std=c++11 -arch=sm_61 --ptxas-options=-v -use_fast_math -use_fast_math --fmad=true -prec-div=false --compiler-options '-fPIC -Wall'
N=1000

solver: nmfa solver.cpp
	g++ -L. -l:cuda_nmfa.so -o solver -Ofast solver.cpp

nmfa: src/nmfa.cu src/cuda_nmfa.h
	python preprocessor.py src/nmfa.cu src/nmfa__preprocessed.cu $(N)
	$(NVCC) $(CUDA_FLAGS) src/nmfa__preprocessed.cu -o cuda_nmfa.so --shared

clean:
	rm cuda_nmfa.so src/nmfa__preprocessed.cu
