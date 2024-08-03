{\rtf1\ansi\ansicpg1252\cocoartf2761
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/bin/bash\
# Begin LSF Directives\
\
#BSUB -W 01:00\
#BSUB -nnodes 4100\
#BSUB -alloc_flags "smt1"\
export CODE_PATH=/gpfs/alpine2/redacted/\
proj-shared/redacted/mpiGraph \
\
exec=$\{CODE_PATH\}/mpiGraph\
\
NNODES_ARR=\{128, 512, 1024, 4096\}\
\
for NNODES in $\{NNODES_ARR[@]\}; do\
echo "Starting NNODES=$\{NNODES\}"\
jsrun -n $\{NNODES\} -r 1 -a 1 -c 1 -g 1 -d packed \
$exec 8388608 10 2\
\
done}