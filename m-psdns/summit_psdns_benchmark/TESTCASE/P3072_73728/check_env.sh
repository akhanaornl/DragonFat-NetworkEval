#!/bin/bash

export CODE_PATH=/gpfs/alpine2/project/proj-shared/$USER/SUMMIT
source ${CODE_PATH}/setUpModules.sh

module list

exec=${CODE_PATH}/MPI_A2A.x


ls -ltr $exec

