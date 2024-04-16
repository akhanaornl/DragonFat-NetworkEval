#!/bin/bash
#BSUB -P account
#BSUB -W 00:10
#BSUB -nnodes 216
#BSUB -J Ember_Halo3d-26_Summit_216
#BSUB -o Ember_Halo3d-26_Summit_216-%J.out

module load cuda
export OMP_NUM_THREADS=1

exe=/ccs/home/user/proj-shared-alpine2/ember/DragonFly/mpi/halo3d-26/halo3d-26
exe_basename=halo3d-26

ds=512
nv=50
it=1024
np=216

n=$(expr ${np} \* 6)
ps=$(printf '%1.0f\n' `echo "e(l($np)/3)" | bc -l`)
echo "### RUNNING ${np} NODES!!!!"

set -x
jsrun -n $n -r 6 -a 1 -c 1 -g 1 -d packed --smpiargs="-gpu" \
	${exe} -nx $ds -ny $ds -nz $ds -pex $ps -pey $(expr $ps \* 2) -pez $(expr $ps \* 3) -vars $nv -iterations $it
exit_code=$?
set +x
echo "Completed with exit code: $exit_code"

