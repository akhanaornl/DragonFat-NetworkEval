#!/bin/bash
#SBATCH -A account
#SBATCH -J Ember_Halo3d-26_Frontier
#SBATCH -o %x-%j.out
#SBATCH -t 45
#SBATCH -N 9261
#SBATCH -c 7
#SBATCH -n 74088
#SBATCH --gpus-per-task 1
#SBATCH --gpu-bind closest

WORKDIR=${SLURM_SUBMIT_DIR}/${SLURM_JOB_NAME}
mkdir -p ${WORKDIR}
cd ${WORKDIR}

module load cpe/22.12
module load craype-accel-amd-gfx90a
module load amd-mixed
export MPICH_GPU_SUPPORT_ENABLED=1
export OMP_NUM_THREADS=1

exe=/ccs/home/user/proj-shared-orion/user/ember/DragonFly/mpi/halo3d-26/halo3d-26_hip
exe_basename=halo3d-26_hip

# Use sbcast to pre-stage binary & NFS/Lustre-hosted libs if you can
sbcast -pf --send-libs ${exe} /tmp/${exe_basename}

# pre-pend /tmp/${exe_basename}_libs to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/tmp/${exe_basename}_libs:${LD_LIBRARY_PATH}
exe=/tmp/${exe_basename}

# Launch a job for shasta_addr
set -x
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 ${SLURM_SUBMIT_DIR}/make_network_groups/shasta_addr 4 | sort > dragonfly_topo.txt
set +x

sleep 1

ds=512
nv=50
it=1024

for np in 64 125 216 343 512 1728 4096 8000 9261; do
    n=$(expr ${np} \* 8)
    ps=$(printf '%1.0f\n' `echo "e(l($n)/3)" | bc -l`)
    echo "### RUNNING ${np} NODES!!!!"

    # Ordered
    mkdir -p ${np}_ordered
    cd ${np}_ordered
    nodelist=$(${SLURM_SUBMIT_DIR}/make_network_groups/give_me_nodes_frontier.py -N ${np} --key=${WORKDIR}/dragonfly_topo.txt)
    set -x
    srun -v -N $np -n $n -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered -w ${nodelist} --export=ALL \
        ${exe} -nx $ds -ny $ds -nz $ds -pex $ps -pey $ps -pez $ps -vars $nv -iterations $it

    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"
    cd ${WORKDIR}
    
    # Random
    mkdir -p ${np}_random
    cd ${np}_random
    nodelist=$(${SLURM_SUBMIT_DIR}/make_network_groups/give_me_nodes_frontier.py -N ${np} --randomize --reorder-file rank_reorder.${SLURM_JOBID}.${np} --key=${WORKDIR}/dragonfly_topo.txt)
    export MPICH_RANK_REORDER_METHOD=3
    export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.${np}
    set -x
    srun -v -N $np -n $n -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered -w ${nodelist} --export=ALL \
        ${exe} -nx $ds -ny $ds -nz $ds -pex $ps -pey $ps -pez $ps -vars $nv -iterations $it
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"
    cd ${WORKDIR}
    
    # Unset these so that they don't interfere with the next run
    unset MPICH_RANK_REORDER_FILE
    unset MPICH_RANK_REORDER_METHOD
done
