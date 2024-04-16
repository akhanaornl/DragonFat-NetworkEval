#!/bin/bash

#SBATCH -A Project
#SBATCH -J mpi-a2a-pencil-4096
#SBATCH -o stdout-4096.%J
#SBATCH -e stderr-4096.%J
#SBATCH -t 00:2:00
#SBATCH -p batch
#SBATCH -q debug
#SBATCH -N 4096
#SBATCH --threads-per-core=1
##SBATCH --threads-per-core=2

export CODE_PATH=/lustre/orion/proj-shared/project/hvac/network_eval/FRONTIER
source $CODE_PATH/setUpModules.sh

module list

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

export HIP_LAUNCH_BLOCKING=1

exec=$CODE_PATH/MPI_A2A.x

## add --unbuffered for I/O when debugging

#Runtime Calculation
start_time=$(date +%s)  # Record the start time in seconds

## for --threads-per-core=1
export OMP_NUM_THREADS=7
srun -N4096 -n32768 -c7 --ntasks-per-gpu=1 --gpu-bind=closest $exec

end_time=$(date +%s)  # Record the end time in seconds
total_runtime=$((end_time - start_time))  # Calculate the total runtime in seconds

# Print the total runtime to stdout
echo "Total Job Runtime: ${total_runtime} seconds"
