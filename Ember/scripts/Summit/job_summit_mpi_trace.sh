#!/bin/bash
#BSUB -P account
#BSUB -W 02:00
#BSUB -q debug
#BSUB -nnodes 125
#BSUB -J Ember_Halo3d-26_Summit_nocube_trace
#BSUB -o Ember_Halo3d-26_Summit_nocube_trace-%J.out

module load cuda

WORKDIR=${LS_SUBCWD}/Ember_Halo3d-26_Summit_nocube_trace
mkdir -p ${WORKDIR}
cd ${WORKDIR}

export OMP_NUM_THREADS=1

exe=/ccs/home/user/proj-shared-alpine2/ember/DragonFly/mpi/halo3d-26/halo3d-26
exe_basename=halo3d-26

ds=512
nv=50
it=1024

export LD_PRELOAD=/ccs/home/user/proj-shared-alpine2/ember/mpi_trace_summit_nvcc.so

for np in 125; do
    n=$(expr ${np} \* 6)
    ps=$(printf '%1.0f\n' `echo "e(l($np)/3)" | bc -l`)
    echo "### RUNNING ${np} NODES!!!!"

    # Ordered
    mkdir -p ${np}_ordered
    cd ${np}_ordered
    nodelist=$(${LS_SUBCWD}/make_network_groups/give_me_nodes_summit.py -N ${np} --erf-file ${LSB_JOBID}.${np}.best.erf --node-file $LSB_DJOB_HOSTFILE)
    export TRACE_FILE_PATH=${PWD}
    set -x
    jsrun --erf_input ${LSB_JOBID}.${np}.best.erf --smpiargs="-gpu" stdbuf -i0 -o0 -e0 \
	    ${exe} -nx $ds -ny $ds -nz $ds -pex $ps -pey $(expr $ps \* 2) -pez $(expr $ps \* 3) -vars $nv -iterations $it
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"
    cd ${WORKDIR}
    
    # Random
    mkdir -p ${np}_random
    cd ${np}_random
    nodelist=$(${LS_SUBCWD}/make_network_groups/give_me_nodes_summit.py -N ${np} --erf-file ${LSB_JOBID}.${np}.worst.erf --node-file $LSB_DJOB_HOSTFILE --worst)
    export TRACE_FILE_PATH=${PWD}
    set -x
    jsrun --erf_input ${LSB_JOBID}.${np}.worst.erf --smpiargs="-gpu" stdbuf -i0 -o0 -e0 \
	    ${exe} -nx $ds -ny $ds -nz $ds -pex $ps -pey $(expr $ps \* 2) -pez $(expr $ps \* 3) -vars $nv -iterations $it
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"
    cd ${WORKDIR}
done
