# LAMMPS

## How LAMMPS stressed the network:

LAMMPS stresses communication in two ways -- nearest-neighbor particle exchange and solving FFTs.
The nearest-neighbor particle exchange sends data between two neighboring processes in a 3-D processor grid.
This sends a large amount of data, but usually between processors on the same node or in neighboring nodes.
LAMMPS also computes large 3D FFTs using a particle-particle, particle-mesh solver, which scales with N-logN.
The FFTs are computed via the hipFFT library, and data is exchanged among processes using ``MPI_Send`` with non-blocking Receives to form an All-to-All communication pattern.
This implementation of data exchange stresses the network hardware in both the number of messages and the size of the messages in flight.
-- NOTE: I have exact numbers to support this point in the paper, I don't think I need to repeat them here.

## Reproducibility:

The SPC/E LAMMPS benchmark is provided by the OLCF-6 benchmarks, https://www.olcf.ornl.gov/benchmarks/.
All node counts of this benchmark must be perfect cubes.

### Default runs

The ``default`` runs performed use the OLCF-6 LAMMPS benchmarks without modification.
To reproduce the ``default`` runs, the following commands may be issued:
```
# Build the benchmark
cd build
./build_lammps_gpu.sh
cd ../benchmarks/spce/
# Choose a benchmark size according to the README located in the root of the repository
cd ./2_medium
# Tell the submit wrapper what project to submit for:
export BENCH_PROJECT_ID="ABC123"
# Run the submit wrapper -- this automatically sets node count, time limit, and project
./submit_helper.sh gpu
# Results will propagate in the current directory
```

### Environment modification
The environment can be modified using the shell scripts contained in ``$BENCHMARK_ROOT/common_files/environment``.

### Input files
The input files used are located in ``$BENCHMARK_ROOT/common_files/lammps_inputs/spce`` and symbolically linked to each benchmark directory.
The SPC/E model requires the system data file (``w32k.data.gz``), the LAMMPS input script (``input.in``), and the forcefield parameterization file (``spce.ff.lmp``).
The file ``$BENCHMARK_ROOT/benchmarks/spce/base_size_cmd.txt`` specifies the per-node system replication factor.
The base system is 98,304 atoms, so the default base_size of 8 means to replicate the system 8x8x8 to populate 50.3 million atoms per node.
Additionally, in each benchmark directory, there is a file named ``kokkos_args.txt``, which is optional and contains the keywords to pass to the LAMMPS ``package kokkos`` command.

### Block/random runs

The block/random runs require a new directory to be made in ``$BENCHMARK_ROOT/benchmarks/spce``. See the following Bash commands:

```
$ cd $BENCHMARK_ROOT/benchmarks/spce
$ mkdir network_scaling
# Link LAMMPS input files in
$ ln -s ../../../common_files/lammps_inputs/spce/w32k.data.gz .
$ ln -s ../../../common_files/lammps_inputs/spce/input.in .
$ ln -s ../../../common_files/lammps_inputs/spce/spce.ff.lmp .
# Link scripts required to interpret Frontier network topology
$ ln -s /path/to/give_me_nodes_frontier.py .
$ ln -s /path/to/shasta_addr .
# Optional: copy the ``package kokkos`` arguments from the large system to this directory
$ cp ../4_large/kokkos_args.txt
```

The following batch script was used (also available as `run_network_test.slurm` in the current directory.
```
#!/bin/bash

#SBATCH -A project
#SBATCH -t 75
#SBATCH -N 9261
#SBATCH -J lammps_network_scaling
#SBATCH -o %x-%j.out

source ../../../common_files/environment/setup_env_gpu.sh

# Requires ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp
exe=""
if [ -f ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp ]; then
    exe=$(realpath ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp)
else
    echo "Could not find binary in ${BENCHMARK_ROOT}/build/lammps/install-gpu/bin/lmp"
    exit 1
fi
echo "Sending the binary found in $exe to node-local /tmp..."

exe_basename=$(basename ${exe})

# If this job is wrapped inside another job, the sbcast may have already been performed
if [ ! -f /tmp/${exe_basename} ]; then
    sbcast -pf --send-libs ${exe} /tmp/${exe_basename}
fi
# pre-pend /tmp/${exe_basename}_libs to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/tmp/${exe_basename}_libs:${LD_LIBRARY_PATH}
exe=/tmp/${exe_basename}

if [ ! -f ../base_size_cmd.txt ]; then
    echo "Could not find the required 'base_size_cmd.txt' file in $(realpath ${PWD}/..). Aborting run."
    exit 1
fi
size_cmd=$(head -n 1 ../base_size_cmd.txt)
echo "Using base system size multiplier: ${size_cmd}"

kokkos_args=""
if [ -f kokkos_args.txt ]; then
    kokkos_args=$(head -n 1 kokkos_args.txt)
    echo "Found additional Kokkos arguments: ${kokkos_args}"
fi

export OMP_NUM_THREADS=7
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# Launch a job to get the network address from each node in the job
set -x
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 ./shasta_addr 4 | sort > dragonfly_topo.txt
set +x

sleep 1

# BEGIN #############################
# Beginning size
TMP_SLURM_NNODES_ARR=(64 512 4096 9261)

for TMP_SLURM_NNODES in ${TMP_SLURM_NNODES_ARR[@]}; do
    echo "Starting SLURM_NNODES=${TMP_SLURM_NNODES}"
    nodelist=$(./give_me_nodes.py -N ${TMP_SLURM_NNODES})
    set -x
    srun -N ${TMP_SLURM_NNODES} -n $(expr ${TMP_SLURM_NNODES} \* 8) -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered \
        -w ${nodelist} \
        ${exe} -k on g 1 -sf kk -pk kokkos gpu/aware on ${kokkos_args} \
        -in input.in -log none ${size_cmd} -v nnodes ${TMP_SLURM_NNODES} -v nsteps 50
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"

    # Now run the random reordering problem
    nodelist=$(./give_me_nodes.py -N ${TMP_SLURM_NNODES} --randomize --reorder-file rank_reorder.${SLURM_JOBID}.${TMP_SLURM_NNODES})
    export MPICH_RANK_REORDER_METHOD=3
    export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.${TMP_SLURM_NNODES}
    set -x
    srun -N ${TMP_SLURM_NNODES} -n $(expr ${TMP_SLURM_NNODES} \* 8) -c 7 --gpus-per-task=1 --gpu-bind=closest --unbuffered \
        -w ${nodelist} \
        ${exe} -k on g 1 -sf kk -pk kokkos gpu/aware on ${kokkos_args} \
        -in input.in -log none ${size_cmd} -v nnodes ${TMP_SLURM_NNODES} -v nsteps 50
    exit_code=$?
    set +x
    echo "Completed with exit code: $exit_code"
    unset MPICH_RANK_REORDER_FILE
    unset MPICH_RANK_REORDER_METHOD
done
```

### MPI tracing experiments

All MPI tracing experiments were performed using the utility provided at https://github.com/hagertnl/mpi-trace.
To build, follow the following instructions:

```
$ cd trace-wrapper
# Edit Makefile, if needed. Here is an example to build the wrapper for PrgEnv-amd on Frontier:
$ module load PrgEnv-amd
$ make frontier_amd
```

The ``frontier_amd`` Make target uses ``amdclang++`` to build the library, linking to the currently-loaded MPICH.
This same library can also be used on Summit, which uses ``mpicxx`` as the compiler.
The ``summit`` Make target is included.

To run this MPI trace wrapper, simply ``LD_PRELOAD`` the wrapper in your ``srun`` or ``jsrun`` command:
```
srun --export=ALL,LD_PRELOAD=/path/to/libmpi_trace.so ...
or 
jsrun -E LD_PRELOAD=/path/to/libmpi_trace.so ...
```

Some basic analysis scripts are provided in the ``analysis`` directory of the mpi-trace repository.
The scripts used to generate results used in the paper are ``get_max_mpi_time_sampling.sh`` and ``get_largest_buffer_size_sampling.sh``.
