#!/bin/bash
source ./env
module -t list
set -x
rm -f all
nvcc -I. -x cu -arch=sm_60 -std=c++17 -g -O3 -c ../all.cc
mpiCC -g -O -o all all.o -L${CUDA_DIR}/lib64 -lcudart

