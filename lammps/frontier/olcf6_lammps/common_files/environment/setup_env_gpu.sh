#!/bin/bash

# Reset to default modules -- purge is not recommended on Cray machines
module reset

# Restore the exact compiler, MPI library, and tools we want
module load PrgEnv-amd/8.5.0
# Use December Cray-PE -- compatible with ROCm/5.7.1
module load cpe/23.12
#module load amd/5.5.1
module load amd/5.7.1
module load hwloc/2.5.0

module unload darshan-runtime

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}
export MPICH_GPU_SUPPORT_ENABLED=1

export BENCHMARK_ROOT=$(dirname $(dirname $(dirname $(realpath "$BASH_SOURCE"))))
