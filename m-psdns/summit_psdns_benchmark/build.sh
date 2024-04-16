#!/bin/bash

source setUpModules.sh

module list

gmake -f Makefile realclean
gmake -f Makefile

# check the executable in this environment
ldd MPI_A2A.x
