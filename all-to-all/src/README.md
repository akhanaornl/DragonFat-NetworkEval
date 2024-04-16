# All to All
This benchark measures the performance of `MPI_Alltoall` using a triply nested loop of calls.

- outer: Loop over sizes of concurrent subcommunicators, `targetSize = <size of MPI_COMM_WORLD>..1`, decreasing by half per iteration.
  - middle: Loop over `count` argument sizes, `count = countAll/targetSize..1`, decreasing by half per iteration, where `countAll` is the buffer size in `MPI_LONG`s, based on an optional third command-line argument, `countHi`, times the size of `MPI_COMM_WORLD`, where `countHi` defaults to `40*1024`. Non-positive arguments result in the default.
    - inner: Loop over all-to-all calls, `i = 1..iters`, where `iters` is an optional second command-line argument that defaults to 3. Non-positive arguments result in the default.

The standard output is text that can be used with Gnuplot or PyPlot. The output includes a block of lines for each outer-loop iteration, a data line for each middle-loop iteration, and a comment line (`###`) for each inner-loop iteration.

Each middle-loop output line lists the following.
- The number of concurrent communicators.
- The number of ranks in each communicator (where the last communicator may have fewer if the numbers don't divide).
- The total message size per rank, in GiB: `(sendcount + recvcount) * comm_size * sizeof(long)`.
- The minimum, average, and maximum times for each `MPI_Alltoall`, where the statistics are across all the inner-loop iterations. The measurement for the time of _each_ iteration is itself the maximum time measured across all the ranks.
- The minimum, average, and maximum bandwidths per rank for each `MPI_Alltoall`, based on the total message size per rank divided by the time, given in GiB/s.

The default assignment of tasks to subcommunicators uses contiguous blocks. For example, the second iteration of the outer loop splits `MPI_COMM_WORLD` into a communicator with the first half of the tasks, as numbered by rank, and a communicator with the second half. An optional first command-line argument beginning with 's' requests a strided assignment, where tasks within each communicator are spread out. For example, the second iteration of the outer loop splits `MPI_COMM_WORLD` into a communictor with the odd-rank tasks and a communicator with the even-rank tasks. The penultimate iteration uses many two-task communicators, where the task pairs have `MPI_COMM_WORLD` ranks that differ by half the size of `MPI_COMM_WORLD`. An argument that begins with anything other than 's' or 'S' results in the default contiguous partioning of tasks.

## Building
See the machine directories for sample build (`make.sh`) and batch-run (`job.sh`) scripts.Edit the `env` file to load appropriate software versions.

## Running Examples
Run with the default subcommunicator partitioning of contiguous tasks, the default number of iterations, and the default maximum count size.
```
srun ... -c7 --gpus-per-task=1 --gpu-bind=closest ./all
```
Run with strided partitioning of tasks into subcommunicators:
```
srun ... -c7 --gpus-per-task=1 --gpu-bind=closest ./all strided
```
Run with 10 iterations, with the default other arguments:
```
srun ... -c7 --gpus-per-task=1 --gpu-bind=closest ./all contig 10
```
Run with a maximum count of 128 longs, with the default other arguments.
```
srun ... -c7 --gpus-per-task=1 --gpu-bind=closest ./all contig 0 128
```

