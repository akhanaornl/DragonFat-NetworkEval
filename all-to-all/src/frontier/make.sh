#!/bin/bash
source ./env
module -t list
set -x
rm -f all
hipcc -fopenmp -g -O -I${CRAY_MPICH_DIR}/include -o all ../all.cc -L${CRAY_MPICH_DIR}/lib ${PE_MPICH_GTL_DIR_amd_gfx90a} -lmpi ${PE_MPICH_GTL_LIBS_amd_gfx90a}