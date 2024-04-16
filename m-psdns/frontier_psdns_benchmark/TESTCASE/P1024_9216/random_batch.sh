#!/bin/bash

#SBATCH -A Project
#SBATCH -J m-psdns
#SBATCH -o stdout-128-random.reorder.%J
#SBATCH -e stderr-128-random.reorder..%J
#SBATCH -t 00:2:00
#SBATCH -p batch
#SBATCH -q debug
#SBATCH -N 128
#SBATCH --threads-per-core=1
##SBATCH --threads-per-core=2

export CODE_PATH=/lustre/orion/proj-shared/project/hvac/network_eval/FRONTIER
source $CODE_PATH/setUpModules.sh

#module list

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

export HIP_LAUNCH_BLOCKING=1

exec=$CODE_PATH/MPI_A2A.x

# Launch a job step to get shasta_addr for all nodes
# give_me_nodes_frontier.py needs this to know the network topology
set -x
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 ./shasta_addr 4 | sort > dragonfly_topo.txt
set +x

sleep 1

## add --unbuffered for I/O when debugging

#Runtime Calculation
start_time=$(date +%s)  # Record the start time in seconds

## for --threads-per-core=1
export OMP_NUM_THREADS=7

    # Run the optimal binding case -- must pass this as `-w` to Slurm
    nodelist=$(./give_me_nodes_frontier.py -N ${SLURM_NNODES} --randomize --reorder-file rank_reorder.${SLURM_JOBID})
    export MPICH_RANK_REORDER_METHOD=3
    export MPICH_RANK_REORDER_FILE=rank_reorder.${SLURM_JOBID}
    set -x

srun -N128 -n1024 -c7 --ntasks-per-gpu=1 --gpu-bind=closest -w ${nodelist} $exec
set +x 

end_time=$(date +%s)  # Record the end time in seconds
total_runtime=$((end_time - start_time))  # Calculate the total runtime in seconds

# Print the total runtime to stdout
echo "Total Job Runtime: ${total_runtime} seconds"

