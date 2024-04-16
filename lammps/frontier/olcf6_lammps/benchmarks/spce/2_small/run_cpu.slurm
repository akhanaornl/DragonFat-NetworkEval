#!/bin/bash

#SBATCH -J lammps_benchmark_cpu
#SBATCH -o %x-%j.out

# Ensure that this script is launched from a read-write-able space

source ../../../common_files/environment/setup_env_cpu.sh

benchmark_size=$(basename $(dirname $PWD))
benchmark_name=$(basename $(dirname $(dirname $PWD)))
echo "Running the ${benchmark_name} benchmark, size ${benchmark_size}"

# Requires ${BENCHMARK_ROOT}/build/lammps/install-cpu/bin/lmp
exe=""
if [ -f ${BENCHMARK_ROOT}/build/lammps/install-cpu/bin/lmp ]; then
    exe=$(realpath ${BENCHMARK_ROOT}/build/lammps/install-cpu/bin/lmp)
else
    echo "Could not find binary in ${BENCHMARK_ROOT}/build/lammps/install-cpu/bin/lmp"
    exit 1
fi
echo "Using binary located in: $exe"

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

export OMP_NUM_THREADS=7
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# ``-sf omp -pk omp ${OMP_NUM_THREADS`` enables the OpenMP backend of LAMMPS
# On Frontier, we pack 8 MPI ranks per node, each rank gets 7 CPU cores
srun -N ${SLURM_NNODES} -n $(expr ${SLURM_NNODES} \* 8) -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered \
    ${exe} -sf omp -pk omp ${OMP_NUM_THREADS} \
    -in input.in -log none ${size_cmd} -v nnodes ${SLURM_NNODES}

echo "Completed with exit code: $?"
