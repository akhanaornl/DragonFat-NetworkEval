#!/bin/bash
#SBATCH -A STF006
#SBATCH -p batch
#SBATCH -q debug
#SBATCH -t 0:10:00
#SBATCH -N 512
#SBATCH -J maclaurin
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

TMP_SLURM_NNODES=${SLURM_JOB_NUM_NODES}

for i in lmax08 lmax16 lmax32 lmax64; do
  cat ../../flash.par.base ../../flash.par.$(printf %04d ${SLURM_JOB_NUM_NODES})_nodes ../../flash.par.${i} > flash.par.${i}
  stdbuf -o0 -e0 srun -N ${TMP_SLURM_NNODES} -n $((${TMP_SLURM_NNODES}*8)) -c 7 --ntasks-per-gpu=1 --gpu-bind=closest \
    --export=ALL,LD_PRELOAD=/lustre/orion/stf016/world-shared/hagertnl/installs/mpip/amd5.7.1-mpich8.1.28/lib/libmpiP.so \
    ${exe} -par_file flash.par.${i}
  mkdir -p ${i}
  mv maclaurin.log maclaurin.dat maclaurin_RadialInfoPrint.txt unitTest* ${i}/.
done
