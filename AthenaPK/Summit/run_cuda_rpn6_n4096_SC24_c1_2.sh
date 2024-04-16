#BSUB -nnodes 4096
#BSUB -W 20
#BSUB -P STF243
#BSUB -J athenapk

# Define environment variables needed
EXECUTABLE="athenaPK"
SCRIPTS_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness/summit/athenapk/cuda_rpn6_n4096_SC24_c1-2/Scripts"
WORK_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness_sspace/summit/03.27.24-08.04/athenapk/cuda_rpn6_n4096_SC24_c1-2/1711542057.39224/workdir"
RESULTS_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness/summit/athenapk/cuda_rpn6_n4096_SC24_c1-2/Run_Archive/1711542057.39224"
HARNESS_ID="1711542057.39224"
BUILD_DIR="/gpfs/alpine2/stf243/proj-shared/holmenjk/harness_sspace/summit/03.27.24-08.04/athenapk/cuda_rpn6_n4096_SC24_c1-2/1711542057.39224/build_directory"

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

# LSB_DJOB_HOSTFILE is a file containing the node list in the job. Copying it to help debugging later
cp $LSB_DJOB_HOSTFILE ./job.${LSB_JOBID}.nodes

cp $BUILD_DIR/common_scripts/give_me_nodes_summit.py .

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

#Now run the best ordering problem
nodelist=$(./give_me_nodes_summit.py -N 64 --erf-file ${LSB_JOBID}.64.best.erf --node-file $LSB_DJOB_HOSTFILE)
set -x
jsrun --erf_input ${LSB_JOBID}.64.best.erf \
      --smpiargs="-gpu" \
      stdbuf -i0 -o0 -e0 \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=2048 parthenon/mesh/nx2=2048 parthenon/mesh/nx3=1536 2>&1 | tee output_0064_best.txt
set +x

# Now run the random ordering problem
nodelist=$(./give_me_nodes_summit.py -N 64 --erf-file ${LSB_JOBID}.64.worst.erf --node-file $LSB_DJOB_HOSTFILE --worst)
set -x
jsrun --erf_input ${LSB_JOBID}.64.worst.erf \
      --smpiargs="-gpu" \
      stdbuf -i0 -o0 -e0 \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=2048 parthenon/mesh/nx2=2048 parthenon/mesh/nx3=1536 2>&1 | tee output_0064_rand.txt
set +x

#Now run the best ordering problem
nodelist=$(./give_me_nodes_summit.py -N 512 --erf-file ${LSB_JOBID}.512.best.erf --node-file $LSB_DJOB_HOSTFILE)
set -x
jsrun --erf_input ${LSB_JOBID}.512.best.erf \
      --smpiargs="-gpu" \
      stdbuf -i0 -o0 -e0 \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=4096 parthenon/mesh/nx2=4096 parthenon/mesh/nx3=3072 2>&1 | tee output_0512_best.txt
set +x

# Now run the random ordering problem
nodelist=$(./give_me_nodes_summit.py -N 512 --erf-file ${LSB_JOBID}.512.worst.erf --node-file $LSB_DJOB_HOSTFILE --worst)
set -x
jsrun --erf_input ${LSB_JOBID}.512.worst.erf \
      --smpiargs="-gpu" \
      stdbuf -i0 -o0 -e0 \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=4096 parthenon/mesh/nx2=4096 parthenon/mesh/nx3=3072 2>&1 | tee output_0512_rand.txt
set +x

#Now run the best ordering problem
nodelist=$(./give_me_nodes_summit.py -N 4096 --erf-file ${LSB_JOBID}.4096.best.erf --node-file $LSB_DJOB_HOSTFILE)
set -x
jsrun --erf_input ${LSB_JOBID}.4096.best.erf \
      --smpiargs="-gpu" \
      stdbuf -i0 -o0 -e0 \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=8192 parthenon/mesh/nx2=8192 parthenon/mesh/nx3=6144 2>&1 | tee output_4096_best.txt
set +x

# Now run the random ordering problem
nodelist=$(./give_me_nodes_summit.py -N 4096 --erf-file ${LSB_JOBID}.4096.worst.erf --node-file $LSB_DJOB_HOSTFILE --worst)
set -x
jsrun --erf_input ${LSB_JOBID}.4096.worst.erf \
      --smpiargs="-gpu" \
      stdbuf -i0 -o0 -e0 \
      $BUILD_DIR/athenapk/build/bin/$EXECUTABLE \
      -i $BUILD_DIR/common_scripts/inputs/linear_wave3d.in \
      parthenon/meshblock/nx1=256 parthenon/meshblock/nx2=256 parthenon/meshblock/nx3=256 \
      parthenon/time/nlim=100 \
      parthenon/mesh/nx1=8192 parthenon/mesh/nx2=8192 parthenon/mesh/nx3=6144 2>&1 | tee output_4096_rand.txt
set +x

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

