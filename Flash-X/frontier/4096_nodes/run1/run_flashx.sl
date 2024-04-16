#!/bin/bash
#SBATCH -A STF006
#SBATCH -p batch
##SBATCH -q debug
#SBATCH -t 2:00:00
#SBATCH -N 4096
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

#exe="flashx"
#sbcast --send-libs -pf ${exe} /mnt/bb/$USER/${exe}
## Check to see if file exists
#echo "*****ls -lh /mnt/bb/$USER*****"
#ls -lh /mnt/bb/$USER/
#echo "*****ls -lh /mnt/bb/$USER/${exe}_libs*****"
#ls -lh /mnt/bb/$USER/${exe}_libs
#
#export LD_LIBRARY_PATH="/mnt/bb/$USER/${exe}_libs:${LD_LIBRARY_PATH}"

cp ../../flashx .
for i in lmax08 lmax16 lmax32 lmax64; do
  cat ../../flash.par.base ../../flash.par.$(printf %04d ${SLURM_JOB_NUM_NODES})_nodes ../../flash.par.${i} > flash.par.${i}
  stdbuf -o0 -e0 srun -N $SLURM_JOB_NUM_NODES -n $((${SLURM_JOB_NUM_NODES}*8)) -c 7 --ntasks-per-gpu=1 --gpu-bind=closest ./flashx -par_file flash.par.${i}
  mkdir -p ${i}
  mv maclaurin.log maclaurin.dat maclaurin_RadialInfoPrint.txt unitTest* ${i}/.
done
