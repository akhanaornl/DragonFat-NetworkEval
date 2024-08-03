{\rtf1\ansi\ansicpg1252\cocoartf2761
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/bin/bash\
#SBATCH -t 01:00:00\
#SBATCH -N 8200\
#SBATCH --threads-per-core=1\
export CODE_PATH=/lustre/orion/proj-shared/redacted/hvac/network_eval/mpiGraph\
exec=$\{CODE_PATH\}/mpiGraph\
\
NNODES_ARR=\{128, 512, 1024, 4096, 8192\}\
\
for NNODES in $\{NNODES_ARR[@]\}; do\
echo "Starting NNODES=$\{NNODES\}"\
srun -N $\{NNODES\} -n $\{NNODES\} -c7 --ntasks-per-gpu=1 --gpu-bind=closest $exec 8388608 2 2\
\
done}