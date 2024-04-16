#!/bin/bash
#SBATCH -A account
#SBATCH -J Ember_Halo3d-26_GS
#SBATCH -o %x-%j.out
#SBATCH -t 30
#SBATCH -N 64
#SBATCH -c 7
#SBATCH -n 512
#SBATCH --gpus-per-task 1
#SBATCH --gpu-bind closest

px=8
py=8
pz=8
# ds=1024 Iter
nv=50
it=1024

module load craype-accel-amd-gfx90a rocm
export MPICH_GPU_SUPPORT_ENABLED=1
export OMP_NUM_THREADS=1

for ds in 64 128 256 512 1024; do
    echo "$ds " `srun ./halo3d-26_hip -nx $ds -ny $ds -nz $ds -pex $px -pey $py -pez $pz -vars $nv -iterations $it | grep -A 1 Time`
done

