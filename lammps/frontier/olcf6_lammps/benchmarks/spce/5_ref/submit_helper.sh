#!/bin/bash

# Usage: ./submit_helper.sh <"rfp"|"gpu">
job_file=""
if [ "$1" == "cpu" ]; then
    job_file="run_cpu.slurm"
elif [ "$1" == "gpu" ]; then
    job_file="run_gpu.slurm"
else
    echo "Usage: ./submit_helper.sh <'cpu'|'gpu'>"
    exit 1
fi


# Submits a job using environment-supplied parameters:
#   - BENCH_PROJECT_ID -- the project to use when submitting to the scheduler

# Automatically parses the number of nodes (for Frontier) by the benchmark name & size
benchmark_size=$(basename $PWD)
benchmark_name=$(basename $(dirname $PWD))
nnodes=0
# default walltime -- 1 hour
walltime="60"

if [ "$benchmark_name" == "spce" ]; then
    if [ "$benchmark_size" == "0_nano" ]; then
        # tiny is a 1-node, 6-rank example
        nnodes=1
        walltime="10"
    elif [ "$benchmark_size" == "1_tiny" ]; then
        # small is an 8-node, 48-rank example
        nnodes=8
        walltime="10"
    elif [ "$benchmark_size" == "2_small" ]; then
        # medium is an 64-node, 384-rank example
        nnodes=64
        walltime="20"
    elif [ "$benchmark_size" == "3_medium" ]; then
        # ref is an 512-node, 3072-rank example
        nnodes=512
        walltime="30"
    elif [ "$benchmark_size" == "4_large" ]; then
        # ref is an 512-node, 3072-rank example
        nnodes=4096
        walltime="30"
    elif [ "$benchmark_size" == "5_ref" ]; then
        # ref is an 4096-node, 24576-rank example
        nnodes=9261
        walltime="45"
    fi
elif [ "$benchmark_name" == "reaxff" ]; then
    # ReaxFF scales very well, most node counts finish within 10 minutes on Frontier
    walltime=10
    if [ "$benchmark_size" == "0_nano" ]; then
        # Nano is a 1-node, 8-rank example
        nnodes=1
    elif [ "$benchmark_size" == "1_tiny" ]; then
        # Tiny is an 8-node, 64-rank example
        nnodes=8
    elif [ "$benchmark_size" == "2_small" ]; then
        # Small is an 64-node, 512-rank example
        nnodes=64
    elif [ "$benchmark_size" == "3_medium" ]; then
        # Medium is an 512-node, 4096-rank example
        nnodes=512
    elif [ "$benchmark_size" == "4_large" ]; then
        # Large is 4096-node, 32768-rank
        nnodes=4096
    elif [ "$benchmark_size" == "5_ref" ]; then
        # Ref is 9261-node, 74088-rank
        nnodes=9261
    fi
fi

if [ "$nnodes" == "0" ]; then
    echo "Could not find the correct number of nodes for benchmark=${benchmark_name}, size=${benchmark_size}. Aborting."
    exit 1
fi

if [ "x${BENCH_PROJECT_ID}" == "x" ]; then
    echo "Required to set BENCH_PROJECT_ID in the environment."
    exit 1
fi

echo "sbatch -A ${BENCH_PROJECT_ID} -N ${nnodes} -t ${walltime} ${job_file}"
sbatch -A ${BENCH_PROJECT_ID} -N ${nnodes} -t ${walltime} ${job_file}
