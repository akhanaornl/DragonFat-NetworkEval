#!/bin/bash

#SBATCH -J lammps_benchmark_gpu
#SBATCH -o %x-%j.out
##SBATCH --signal=10@180

# Ensure that this script is launched from a read-write-able space

source ../../../common_files/environment/setup_env_gpu.sh

benchmark_size=$(basename $PWD)
benchmark_name=$(basename $(dirname $PWD))
echo "Running the ${benchmark_name} benchmark, size ${benchmark_size}"

# Requires ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp
exe=""
if [ -f ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp ]; then
    exe=$(realpath ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp)
else
    echo "Could not find binary in ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp"
    exit 1
fi
echo "Sending the binary found in $exe to node-local /tmp..."

exe_basename=$(basename ${exe})

# If this job is wrapped inside another job, the sbcast may have already been performed
if [ ! -f /tmp/${exe_basename} ]; then
    sbcast -pf --send-libs ${exe} /tmp/${exe_basename}
fi
# pre-pend /tmp/${exe_basename}_libs to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/tmp/${exe_basename}_libs:${LD_LIBRARY_PATH}
exe=/tmp/${exe_basename}

# In the current directory, we expect symlinks to the input & data files,
#  as well as a file named ``size_cmd.txt``, which gives us the factors to replicate
#  the unit cell by in X, Y, and Z dimensions.
# Optionally, a file named ``kokkos_args.txt`` may be provided, which supplies
#  additional arguments to the ``package kokkos`` command of LAMMPS.
if [ ! -f ../base_size_cmd.txt ]; then
    echo "Could not find the required 'base_size_cmd.txt' file in $(realpath ${PWD}/..). Aborting run."
    exit 1
fi
size_cmd=$(head -n 1 ../base_size_cmd.txt)
echo "Using base system size multiplier: ${size_cmd}"

kokkos_args=""
if [ -f kokkos_args.txt ]; then
    kokkos_args=$(head -n 1 kokkos_args.txt)
    echo "Found additional Kokkos arguments: ${kokkos_args}"
fi

export OMP_NUM_THREADS=7
export OMP_PROC_BIND=true
export OMP_PLACES=cores

set -x

#export LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so

# ``-k on g 1 -sf kk -pk kokkos gpu/aware on`` are the minimum flags to enable Kokkos for the run.
# On Frontier, we pack 8 MPI ranks per node, each rank gets 7 CPU cores and 1 GCD of an AMD MI250X
srun -N ${SLURM_NNODES} -n $(expr ${SLURM_NNODES} \* 8) -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered \
    ${exe} -k on g 1 -sf kk -pk kokkos gpu/aware on ${kokkos_args} \
    -in input.in -log none ${size_cmd} -v nnodes ${SLURM_NNODES}

exit_code=$?

set +x

echo "Completed with exit code: $exit_code"
