#!/bin/bash
#SBATCH -A account
#SBATCH -J Ember_Halo3d-26_Frontier_1728
#SBATCH -o %x-%j.out
#SBATCH -t 10
#SBATCH -N 1728
#SBATCH -c 7
#SBATCH -n 13824
#SBATCH --gpus-per-task 0
#SBATCH --gpu-bind closest


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

ds=512
nv=50
it=1024
np=1728

n=$(expr ${np} \* 8)
ps=$(printf '%1.0f\n' `echo "e(l($n)/3)" | bc -l`)
echo "### RUNNING ${np} NODES!!!!"

set -x
srun -v -N $np -n $n -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered --export=ALL \
    ${exe} -nx $ds -ny $ds -nz $ds -pex $ps -pey $ps -pez $ps -vars $nv -iterations $it

exit_code=$?
set +x
echo "Completed with exit code: $exit_code"

