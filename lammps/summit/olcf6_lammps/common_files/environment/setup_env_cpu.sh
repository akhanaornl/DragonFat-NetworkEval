#!/bin/bash

module purge

# Restore the exact compiler, MPI library, and tools we want
#module load spectrum-mpi/10.4.0.3-20210112
module load spectrum-mpi/10.4.0.6-20230210
module load lsf-tools/2.0
module load hsi/5.0.2.p5
module load xalt/1.2.1
module load fftw/3.3.10

export BENCHMARK_ROOT=$(dirname $(dirname $(dirname $(realpath "$BASH_SOURCE"))))
