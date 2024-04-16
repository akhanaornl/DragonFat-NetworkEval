#!/bin/bash -l
#SBATCH -J athenapk
#SBATCH -N 64
#SBATCH -t 15
#SBATCH -A __project_id__
#SBATCH -o athenapk.o%j
#SBATCH --no-kill

# Define environment variables needed
export EXECUTABLE="athenaPK"
export SCRIPTS_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness/frontier/athenapk/hip_rpn8_n0064_SC24_c3/Scripts"
export WORK_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness_sspace/frontier/03.18.24-13.15/athenapk/hip_rpn8_n0064_SC24_c3/1710787116.9184487/workdir"
export RESULTS_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness/frontier/athenapk/hip_rpn8_n0064_SC24_c3/Run_Archive/1710787116.9184487"
export HARNESS_ID="1710787116.9184487"
export BUILD_DIR="/lustre/orion/stf243/proj-shared/holmenjk/harness_sspace/frontier/03.18.24-13.15/athenapk/hip_rpn8_n0064_SC24_c3/1710787116.9184487/build_directory"

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

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start


set -x
# Statically sets gpus-per-node to 8, so that we get optimal GPU binding regardless of tasks per node. --gpu-bind=closest still binds 1 GCD per rank
srun -n $NUM_PROC -N 64 --ntasks-per-node=${NUM_RANK_PER_NODE} --gpus-per-node=8 --gpu-bind=closest $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=512 parthenon/meshblock/nx3=512 \
      parthenon/time/nlim=${PARTHENON_TIME_NLIM} \
      parthenon/mesh/nx1=${PARTHENON_MESH_NX1} parthenon/mesh/nx2=${PARTHENON_MESH_NX2} parthenon/mesh/nx3=${PARTHENON_MESH_NX3} 2>&1 | tee outputs/output_perf.txt

set +x

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

