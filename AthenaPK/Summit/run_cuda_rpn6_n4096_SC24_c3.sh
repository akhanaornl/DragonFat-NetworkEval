#BSUB -nnodes 4096
#BSUB -W 15
#BSUB -P STF243
#BSUB -J athenapk

# Define environment variables needed
EXECUTABLE="athenaPK"
SCRIPTS_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness/summit/athenapk/cuda_rpn6_n4096_SC24_c3/Scripts"
WORK_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness_sspace/summit/03.21.24-08.33/athenapk/cuda_rpn6_n4096_SC24_c3/1711025086.0829284/workdir"
RESULTS_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness/summit/athenapk/cuda_rpn6_n4096_SC24_c3/Run_Archive/1711025086.0829284"
HARNESS_ID="1711025086.0829284"
BUILD_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness_sspace/summit/03.21.24-08.33/athenapk/cuda_rpn6_n4096_SC24_c3/1711025086.0829284/build_directory"

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
cat $LSB_DJOB_HOSTFILE | grep -v "batch" | uniq > job.nodes

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

CMD="jsrun -n 4096 -a 6 -g 6 -c 42 -r 1 -d packed -b packed:7 --smpiargs='-gpu' \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=8192 parthenon/mesh/nx2=8192 parthenon/mesh/nx3=6144"

echo "$CMD"

$CMD 2>&1 | tee output_perf.txt

log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

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

