#!/bin/bash

source setUpModules.sh

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

module list

# check the executable in this environment
#ldd MPI_A2A.x
printenv | grep ROCM
