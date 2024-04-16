#!/bin/bash

module purge

# Restore the compiler, MPI library, and tools we want
# Uses system-gcc (8.5.0)
module load spectrum-mpi/10.4.0.6-20230210
module load lsf-tools/2.0
module load hsi/5.0.2.p5
module load xalt/1.2.1

# Add CUDA, hwloc, fftw (for host-based PPPM computations)
module load cuda/11.7.1
#module load hwloc/2.5.0
module load fftw/3.3.10

export BENCHMARK_ROOT=$(dirname $(dirname $(dirname $(realpath "$BASH_SOURCE"))))
