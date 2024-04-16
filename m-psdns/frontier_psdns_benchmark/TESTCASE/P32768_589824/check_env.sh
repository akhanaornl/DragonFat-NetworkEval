#!/bin/bash

export CODE_PATH=/lustre/orion/proj-shared/project/hvac/network_eval/FRONTIER
source $CODE_PATH/setUpModules.sh

module list

export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

export HIP_LAUNCH_BLOCKING=1

exec=$CODE_PATH/MPI_A2A.x

ls -ltr $exec

#ldd $exec | grep darshan
