#!/bin/bash

#SBATCH -A <proj>
#SBATCH -t 10
#SBATCH -N 4096
#SBATCH -J network_scaling_example
#SBATCH -o %x-%j.out

# Use sbcast to pre-stage binary & NFS/Lustre-hosted libs if you can
sbcast -pf --send-libs ${exe} /tmp/${exe_basename}
# pre-pend /tmp/${exe_basename}_libs to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/tmp/${exe_basename}_libs:${LD_LIBRARY_PATH}
exe=/tmp/${exe_basename}

# Launch a job step to get shasta_addr for all nodes
# give_me_nodes_frontier.py needs this to know the network topology
set -x
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 ./shasta_addr 4 | sort > dragonfly_topo.txt
set +x

sleep 1

# BEGIN #############################

# Specify what sizes you want to run -- ideally you can use this node count to scale your inputs as well
# Otherwise, you might just have to manually unroll this loop
TMP_SLURM_NNODES_ARR=(64 512 4096)

# To enable or disable MPI-P profiling, add this line to your srun line.
# Note, this is how I validate the rank binding to nodes easily
# This might move soon, but I'll @ everyone in Teams if it moves
        #--export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \

for TMP_SLURM_NNODES in ${TMP_SLURM_NNODES_ARR[@]}; do
    echo "Starting SLURM_NNODES=${TMP_SLURM_NNODES}"
    # Run the optimal binding case -- must pass this as `-w` to Slurm
    nodelist=$(./give_me_nodes_frontier.py -N ${TMP_SLURM_NNODES})
    set -x
    srun -N ${TMP_SLURM_NNODES} -n $(expr ${TMP_SLURM_NNODES} \* 8) -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered \
        -w ${nodelist} \
        --export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \
        ${exe}
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"

    # Now run the random reordering problem -- `--randomize` tells the script to take the optimal binding and shuffle the node order
    # This keeps groups of 8 ranks on the same node still
    # Uses python3 random.shuffle()
    nodelist=$(./give_me_nodes_frontier.py -N ${TMP_SLURM_NNODES} --randomize --reorder-file rank_reorder.${SLURM_JOBID}.${TMP_SLURM_NNODES})
    export MPICH_RANK_REORDER_METHOD=3
    export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.${TMP_SLURM_NNODES}
    set -x
    srun -N ${TMP_SLURM_NNODES} -n $(expr ${TMP_SLURM_NNODES} \* 8) -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered \
        -w ${nodelist} \
        --export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \
        ${exe}
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"
    # Unset these so that they don't interfere with the next run
    unset MPICH_RANK_REORDER_FILE
    unset MPICH_RANK_REORDER_METHOD
done

