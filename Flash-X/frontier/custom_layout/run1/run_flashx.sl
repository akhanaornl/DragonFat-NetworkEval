#!/bin/bash
#SBATCH -A STF006
#SBATCH -p batch
##SBATCH -q debug
#SBATCH -t 4:00:00
#SBATCH -N 9261
#SBATCH -J custom_maclaurin
#SBATCH -o %x.%j.out
##SBATCH -C nvme

#module load cpe/23.12
#module load PrgEnv-cray cce/17.0.0 cray-hdf5-parallel craype-accel-amd-gfx90a rocm/5.7.1 hipfort/5.7.1
module load PrgEnv-cray cray-hdf5-parallel
module unload darshan-runtime

export OMP_NUM_THREADS=1
#export OMP_DISPLAY_ENV=VERBOSE
#export OMP_STACKSIZE=2G

#export CRAY_MALLOPT_OFF=TRUE
#export MALLOC_MMAP_MAX_=0 
#export MALLOC_TRIM_THRESHOLD_=$(( 512 * 1024 * 1024 ))

#export HSA_XNACK=0

export PMI_MMAP_SYNC_WAIT_TIME=1800

#sbcast --send-libs -pf ${exe} /mnt/bb/$USER/${exe}
## Check to see if file exists
#echo "*****ls -lh /mnt/bb/$USER*****"
#ls -lh /mnt/bb/$USER/
#echo "*****ls -lh /mnt/bb/$USER/${exe}_libs*****"
#ls -lh /mnt/bb/$USER/${exe}_libs
#
#export LD_LIBRARY_PATH="/mnt/bb/$USER/${exe}_libs:${LD_LIBRARY_PATH}"

cp ../../flashx .

# Use sbcast to pre-stage binary & NFS/Lustre-hosted libs if you can
exe_basename="flashx"
exe="flashx"
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

# Specify what sizes you want to run -- ideally you can use this node count to scale your inputs as well
# Otherwise, you might just have to manually unroll this loop
TMP_SLURM_NNODES_ARR=(64 512 4096 9261)
#TMP_SLURM_NNODES_ARR=(64 512 4096)
#TMP_SLURM_NNODES=${SLURM_JOB_NUM_NODES}

# To enable or disable MPI-P profiling, add this line to your srun line.
# Note, this is how I validate the rank binding to nodes easily
# This might move soon, but I'll @ everyone in Teams if it moves
        #--export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \

for TMP_SLURM_NNODES in ${TMP_SLURM_NNODES_ARR[@]}; do
    echo "Starting SLURM_NNODES=${TMP_SLURM_NNODES}"
    node_rundir=$(printf %04d ${TMP_SLURM_NNODES})_nodes

    # Run the optimal binding case -- must pass this as `-w` to Slurm
    nodelist=$(./give_me_nodes_frontier.py -N ${TMP_SLURM_NNODES})
    cd grouped/${node_rundir}
    for i in lmax08 lmax16 lmax32 lmax64; do
      cat ../../../../flash.par.base ../../../../flash.par.${node_rundir} ../../../../flash.par.${i} > flash.par.${i}

      set -x
      stdbuf -o0 -e0 srun -N ${TMP_SLURM_NNODES} -n $((${TMP_SLURM_NNODES}*8)) -c 7 --ntasks-per-gpu=1 --gpu-bind=closest \
        -w ${nodelist} \
        --export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \
        ${exe} -par_file flash.par.${i}
      exit_code=$?
      set +x
      echo "Completed grouped with exit code: $exit_code (${node_rundir} / ${i})"

      mkdir -p ${i}
      mv maclaurin.log maclaurin.dat maclaurin_RadialInfoPrint.txt unitTest* ${i}/.
    done
    cd ../../

    # Now run the random reordering problem -- `--randomize` tells the script to take the optimal binding and shuffle the node order
    # This keeps groups of 8 ranks on the same node still
    # Uses python3 random.shuffle()
    nodelist=$(./give_me_nodes_frontier.py -N ${TMP_SLURM_NNODES} --randomize --reorder-file rank_reorder.${SLURM_JOBID}.${TMP_SLURM_NNODES})
    export MPICH_RANK_REORDER_METHOD=3
    export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.${TMP_SLURM_NNODES}
    cd random/${node_rundir}
    for i in lmax08 lmax16 lmax32 lmax64; do
      cat ../../../../flash.par.base ../../../../flash.par.${node_rundir} ../../../../flash.par.${i} > flash.par.${i}

      set -x
      stdbuf -o0 -e0 srun -N ${TMP_SLURM_NNODES} -n $((${TMP_SLURM_NNODES}*8)) -c 7 --ntasks-per-gpu=1 --gpu-bind=closest \
        -w ${nodelist} \
        --export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \
        ${exe} -par_file flash.par.${i}
      exit_code=$?
      set +x
      echo "Completed random with exit code: $exit_code (${node_rundir} / ${i})"

      mkdir -p ${i}
      mv maclaurin.log maclaurin.dat maclaurin_RadialInfoPrint.txt unitTest* ${i}/.
    done
    cd ../../

    # Unset these so that they don't interfere with the next run
    unset MPICH_RANK_REORDER_FILE
    unset MPICH_RANK_REORDER_METHOD

done

