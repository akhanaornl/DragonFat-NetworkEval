#!/bin/bash

# Reset to default modules -- purge is not recommended on Cray machines
module reset

# Restore the exact compiler, MPI library, and tools we want
module load PrgEnv-amd/8.5.0
# Use December 2023 Cray-PE -- compatible with ROCm/5.7.1
module load cpe/23.12
module load amd/5.7.1
module load cray-fftw/3.3.10.6

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

export BENCHMARK_ROOT=$(dirname $(dirname $(dirname $(realpath "$BASH_SOURCE"))))
