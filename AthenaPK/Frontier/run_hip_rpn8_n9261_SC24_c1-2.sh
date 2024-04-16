#!/bin/bash -l
#SBATCH -J athenapk
#SBATCH -N 9261
#SBATCH -t 20
#SBATCH -A __project_id__
#SBATCH -o athenapk.o%j
#SBATCH --no-kill

# Define environment variables needed
export EXECUTABLE="athenaPK"
export SCRIPTS_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness/frontier/athenapk/hip_rpn8_n9261_SC24_c1-2/Scripts"
export WORK_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness_sspace/frontier/03.22.24-08.36/athenapk/hip_rpn8_n9261_SC24_c1-2/1711120224.3042455/workdir"
export RESULTS_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness/frontier/athenapk/hip_rpn8_n9261_SC24_c1-2/Run_Archive/1711120224.3042455"
export HARNESS_ID="1711120224.3042455"
export BUILD_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness_sspace/frontier/03.22.24-08.36/athenapk/hip_rpn8_n9261_SC24_c1-2/1711120224.3042455/build_directory"

source $BUILD_DIR/common_scripts/setup_environment.sh
module -t list

TEST_NAME=$(basename $(dirname $(dirname $RGT_TEST_RUNARCHIVE_DIR)))
NUM_NODE=$(echo $TEST_NAME | sed -e 's/.*_n0*\([0-9]*\).*/\1/')
NUM_RANK_PER_NODE=$(echo $TEST_NAME | \
  sed -e 's/.*_rpn0*\([0-9]*\).*/\1/' -e 's/.*[a-zA-Z_].*/1/')
NUM_PROC=$(( $NUM_NODE * $NUM_RANK_PER_NODE ))

echo "Printing test directory environment variables:"
env | fgrep RGT_APP_SOURCE_
env | fgrep RGT_TEST_
echo

# Ensure we are in the starting directory
cd $SCRIPTS_DIR

# Make the working scratch space directory.
if [ ! -e $WORK_DIR ]
then
    mkdir -p $WORK_DIR
fi

# Change directory to the working directory.
cd $WORK_DIR

env &> job.environ
scontrol show hostnames > job.nodes

mkdir outputs

cp $BUILD_DIR/common_scripts/shasta_addr .
cp $BUILD_DIR/common_scripts/give_me_nodes_frontier.py .

# Launch a job step to get shasta_addr for all nodes
# give_me_nodes_frontier.py needs this to know the network topology
set -x
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 ./shasta_addr 4 | sort > dragonfly_topo.txt
set +x

sleep 1

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

# Run the optimal binding case -- must pass this as `-w` to Slurm
nodelist=$(./give_me_nodes_frontier.py -N 64)
set -x
srun -n 512 -N 64 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=2048 parthenon/mesh/nx2=4096 parthenon/mesh/nx3=4096 2>&1 | tee outputs/output_perf_n0064_best.txt
set +x

# Now run the random reordering problem -- `--randomize` tells the script to take the optimal binding and shuffle the node order
# This keeps groups of 8 ranks on the same node still
# Uses python3 random.shuffle()
nodelist=$(./give_me_nodes_frontier.py -N 64 --randomize --reorder-file rank_reorder.${SLURM_JOBID}.64)
export MPICH_RANK_REORDER_METHOD=3
export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.64
set -x
srun -n 512 -N 64 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=2048 parthenon/mesh/nx2=4096 parthenon/mesh/nx3=4096 2>&1 | tee outputs/output_perf_n0064_rand.txt
set +x

# Unset these so that they don't interfere with the next run
unset MPICH_RANK_REORDER_FILE
unset MPICH_RANK_REORDER_METHOD

# Run the optimal binding case -- must pass this as `-w` to Slurm
nodelist=$(./give_me_nodes_frontier.py -N 512)
set -x
srun -n 4096 -N 512 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=4096 parthenon/mesh/nx2=8192 parthenon/mesh/nx3=8192 2>&1 | tee outputs/output_perf_n0512_best.txt
set +x

# Now run the random reordering problem -- `--randomize` tells the script to take the optimal binding and shuffle the node order
# This keeps groups of 8 ranks on the same node still
# Uses python3 random.shuffle()
nodelist=$(./give_me_nodes_frontier.py -N 512 --randomize --reorder-file rank_reorder.${SLURM_JOBID}.512)
export MPICH_RANK_REORDER_METHOD=3
export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.512
set -x
srun -n 4096 -N 512 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=4096 parthenon/mesh/nx2=8192 parthenon/mesh/nx3=8192 2>&1 | tee outputs/output_perf_n0512_rand.txt
set +x

# Unset these so that they don't interfere with the next run
unset MPICH_RANK_REORDER_FILE
unset MPICH_RANK_REORDER_METHOD


# Run the optimal binding case -- must pass this as `-w` to Slurm
nodelist=$(./give_me_nodes_frontier.py -N 4096)
set -x
srun -n 32768 -N 4096 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=8192 parthenon/mesh/nx2=16384 parthenon/mesh/nx3=16384 2>&1 | tee outputs/output_perf_n4096_best.txt
set +x

# Now run the random reordering problem -- `--randomize` tells the script to take the optimal binding and shuffle the node order
# This keeps groups of 8 ranks on the same node still
# Uses python3 random.shuffle()
nodelist=$(./give_me_nodes_frontier.py -N 4096 --randomize --reorder-file rank_reorder.${SLURM_JOBID}.4096)
export MPICH_RANK_REORDER_METHOD=3
export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.4096
set -x
srun -n 32768 -N 4096 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=8192 parthenon/mesh/nx2=16384 parthenon/mesh/nx3=16384 2>&1 | tee outputs/output_perf_n4096_rand.txt
set +x

# Unset these so that they don't interfere with the next run
unset MPICH_RANK_REORDER_FILE
unset MPICH_RANK_REORDER_METHOD

# Run the optimal binding case -- must pass this as `-w` to Slurm
nodelist=$(./give_me_nodes_frontier.py -N 9261)
set -x
srun -n 74088 -N 9261 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=10752 parthenon/mesh/nx2=21504 parthenon/mesh/nx3=21504 2>&1 | tee outputs/output_perf_n9261_best.txt
set +x

# Now run the random reordering problem -- `--randomize` tells the script to take the optimal binding and shuffle the node order
# This keeps groups of 8 ranks on the same node still
# Uses python3 random.shuffle()
nodelist=$(./give_me_nodes_frontier.py -N 9261 --randomize --reorder-file rank_reorder.${SLURM_JOBID}.9261)
export MPICH_RANK_REORDER_METHOD=3
export MPICH_RANK_REORDER_FILE=${PWD}/rank_reorder.${SLURM_JOBID}.9261
set -x
srun -n 74088 -N 9261 --ntasks-per-node=8 --gpus-per-node=8 --gpu-bind=closest --unbuffered -w ${nodelist} \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=10752 parthenon/mesh/nx2=21504 parthenon/mesh/nx3=21504 2>&1 | tee outputs/output_perf_n9261_rand.txt
set +x

# Unset these so that they don't interfere with the next run
unset MPICH_RANK_REORDER_FILE
unset MPICH_RANK_REORDER_METHOD

log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

export failed_nodes=""
if [ "$(sacct -j ${SLURM_JOBID} -X -n | wc -l)" == "1" ]; then
    echo "No node failure detected."
else
    echo "Node failure detected."
    export failed_nodes="found resized job step."
fi
[ ! "x$failed_nodes" == "x" ] && echo "Found failed nodes: $failed_nodes"

# Copy the output and results back to the $RESULTS_DIR
cp -rf $WORK_DIR/* $RESULTS_DIR
cp $BUILD_DIR/output_build* $RESULTS_DIR

# Check the final results.
check_executable_driver.py -p $RESULTS_DIR -i $HARNESS_ID

# Resubmit if needed
case 0 in
    0)
       echo "No resubmit";;
    1)
       test_harness_driver.py -r;;
esac

