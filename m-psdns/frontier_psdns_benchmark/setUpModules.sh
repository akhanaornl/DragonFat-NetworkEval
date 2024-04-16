#!/bin/bash

module load craype-accel-amd-gfx90a
module load rocm/5.5.1

module load cpe/23.09

## These must be set before running with GPU-Aware Cray-MPICH
export MPICH_GPU_SUPPORT_ENABLED=1
