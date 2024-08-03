#!/bin/bash\
#SBATCH -t 01:00:00\
#SBATCH -N 8200\
#SBATCH --threads-per-core=1\
export CODE_PATH=/lustre/orion/proj-shared/redacted/hvac/network_eval/mpiGraph\
exec=$\{CODE_PATH\}/mpiGraph\

NNODES_ARR=\{128, 512, 1024, 4096, 8192\}\

for NNODES in $\{NNODES_ARR[@]\}; do
echo "Starting NNODES=$\{NNODES\}"
srun -N $\{NNODES\} -n $\{NNODES\} -c7 --ntasks-per-gpu=1 --gpu-bind=closest $exec 8388608 2 2

done
