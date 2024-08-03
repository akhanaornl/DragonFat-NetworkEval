#!/bin/bash\
# Begin LSF Directives

#BSUB -W 01:00
#BSUB -nnodes 4100
#BSUB -alloc_flags "smt1"
export CODE_PATH=/gpfs/alpine2/redacted/proj-shared/redacted/mpiGraph 

exec=$\{CODE_PATH\}/mpiGraph

NNODES_ARR=\{128, 512, 1024, 4096\}

for NNODES in $\{NNODES_ARR[@]\}; do
echo "Starting NNODES=$\{NNODES\}"
jsrun -n $\{NNODES\} -r 1 -a 1 -c 1 -g 1 -d packed 
$exec 8388608 10 2

done
