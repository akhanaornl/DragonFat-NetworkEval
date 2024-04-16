#!/bin/bash

# Usage: ./submit_helper.sh <"rfp"|"gpu">
job_file=""
if [ "$1" == "cpu" ]; then
    job_file="run_cpu.bsub"
elif [ "$1" == "gpu" ]; then
    job_file="run_gpu.bsub"
else
    echo "Usage: ./submit_helper.sh <'cpu'|'gpu'>"
    exit 1
fi


# Submits a job using environment-supplied parameters:
#   - BENCH_PROJECT_ID -- the project to use when submitting to the scheduler

# Automatically parses the number of nodes (for Summit) by the benchmark name & size
benchmark_size=$(basename $PWD)
benchmark_name=$(basename $(dirname $PWD))
nnodes=0
# default walltime -- maximum on Summit
walltime="02:00"

if [ "$benchmark_name" == "spce" ]; then
    if [ "$benchmark_size" == "0_tiny" ]; then
        # tiny is a 1-node, 6-rank example
        nnodes=1
        if [ "$1" == "gpu" ]; then
            walltime="00:05"
        fi
    elif [ "$benchmark_size" == "1_small" ]; then
        # small is an 8-node, 48-rank example
        nnodes=8
        if [ "$1" == "gpu" ]; then
            walltime="00:10"
        fi
    elif [ "$benchmark_size" == "2_medium" ]; then
        # medium is an 64-node, 384-rank example
        nnodes=64
        if [ "$1" == "gpu" ]; then
            walltime="00:30"
        fi
    elif [ "$benchmark_size" == "3_large" ]; then
        # ref is an 512-node, 3072-rank example
        nnodes=512
        if [ "$1" == "gpu" ]; then
            walltime="00:30"
        fi
    elif [ "$benchmark_size" == "4_ref" ]; then
        # ref is an 4096-node, 24576-rank example
        nnodes=4096
        if [ "$1" == "gpu" ]; then
            walltime="00:30"
        else
            walltime="00:30"
        fi
    fi
elif [ "$benchmark_name" == "reaxff" ] && [ "$1" == "gpu" ]; then
    if [ "$benchmark_size" == "0_nano" ]; then
        # Nano is a 1-node, 6-rank example
        nnodes=1
        if [ "$1" == "gpu" ]; then
            walltime="00:20"
        fi
    elif [ "$benchmark_size" == "1_tiny" ]; then
        # Tiny is an 8-node, 48-rank example
        nnodes=8
        if [ "$1" == "gpu" ]; then
            walltime="00:20"
        fi
    elif [ "$benchmark_size" == "2_small" ]; then
        # Small is an 64-node, 384-rank example
        nnodes=64
        if [ "$1" == "gpu" ]; then
            walltime="00:20"
        fi
    elif [ "$benchmark_size" == "3_medium" ]; then
        # Medium is an 512-node, 3072-rank example
        nnodes=512
        if [ "$1" == "gpu" ]; then
            walltime="00:20"
        fi
    elif [ "$benchmark_size" == "4_ref" ]; then
        # Ref is an 1/2-summit (2048-node, 12288-rank) example
        nnodes=4096
        if [ "$1" == "gpu" ]; then
            walltime="01:00"
        fi
    fi
elif [ "$benchmark_name" == "reaxff" ] && [ "$1" == "cpu" ]; then
    echo "ReaxFF system does not have a CPU variant."
    exit 1
fi

if [ "$nnodes" == "0" ]; then
    echo "Could not find the correct number of nodes for benchmark=${benchmark_name}, size=${benchmark_size}. Aborting."
    exit 1
fi

if [ "x${BENCH_PROJECT_ID}" == "x" ]; then
    echo "Required to set BENCH_PROJECT_ID in the environment."
    exit 1
fi

echo "bsub -P ${BENCH_PROJECT_ID} -nnodes ${nnodes} -W ${walltime} ${job_file}"
bsub -P ${BENCH_PROJECT_ID} -nnodes ${nnodes} -W ${walltime} ${job_file}
