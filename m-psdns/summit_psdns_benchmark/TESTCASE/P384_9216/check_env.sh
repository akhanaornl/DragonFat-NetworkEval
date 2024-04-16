#!/bin/bash

export CODE_PATH=/ccs/home/$USER/PROJECTS/REPRODUCERS/mpi-a2a-pencil/SUMMIT
source ${CODE_PATH}/setUpModules.sh

module list

exec=${CODE_PATH}/MPI_A2A.x


ls -ltr $exec

