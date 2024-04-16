#!/bin/bash

source setUpModules.sh

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

module list

make -f Makefile realclean
make -f Makefile

# check the executable in this environment
ldd MPI_A2A.x
