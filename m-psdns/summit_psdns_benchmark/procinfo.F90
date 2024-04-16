subroutine procinfo()
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Collect name of node on which each task is running
! Collect associated device ID (GPU)
! Collect CPU-ID on which threads are running
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   use omp_lib
   use mpi
   implicit none

   interface
      function getcpuid() bind(C,name='sched_getcpu')
         integer :: getcpuid
      end function
   end interface

   character(len=MPI_MAX_PROCESSOR_NAME) :: nodename
   integer :: resultlen,ierr
   integer :: taskid,numtasks,itask
   integer :: num_thr,ithr,st,en,stride
   integer, allocatable :: cpuid(:),cpuid_all(:,:)
   integer :: gpuid
   integer, allocatable :: gpuid_all(:)
   character(len=:), allocatable :: nodename_all(:)

!!!! Get name of node on which each task is running 
   call MPI_COMM_SIZE (MPI_COMM_WORLD,numtasks,ierr)
   call MPI_COMM_RANK (MPI_COMM_WORLD,taskid,ierr)

   call MPI_GET_PROCESSOR_NAME(nodename,resultlen,ierr)

   allocate(character(resultlen) :: nodename_all(numtasks))

   call MPI_GATHER(nodename,resultlen,MPI_CHAR,nodename_all,resultlen,&
      MPI_CHAR,0,MPI_COMM_WORLD,ierr)

!!!! Get cpuid of each thread
   num_thr=0
   !$OMP PARALLEL
   
   !$ num_thr=OMP_GET_NUM_THREADS()

   !$OMP END PARALLEL

   allocate(cpuid(num_thr))
   allocate(cpuid_all(num_thr,numtasks))

   ithr=0
   cpuid(:)=0
   !$OMP PARALLEL PRIVATE(ithr)

   !$ ithr=OMP_GET_THREAD_NUM()
   cpuid(ithr+1)=getcpuid()

   !$OMP END PARALLEL

   call MPI_GATHER(cpuid,num_thr,MPI_INTEGER,cpuid_all,num_thr,&
      MPI_INTEGER,0,MPI_COMM_WORLD,ierr)

!!!! Get gpuid for each task
   gpuid=0
   !$ gpuid=OMP_GET_DEFAULT_DEVICE()

   allocate(gpuid_all(numtasks))
   
   call MPI_GATHER(gpuid,1,MPI_INTEGER,gpuid_all,1,&
      MPI_INTEGER,0,MPI_COMM_WORLD,ierr)

!!!! Print to file procinfo
   if(taskid.eq.0) then
      open(61,file='procinfo')
      write(61,"('TASKID',2x,1x,'START',2x,'END',1x,2x,'STRIDE', &
     &   2x,'GPU-ID',8x,'NODE-ID')")
      do itask=1,numtasks
         st=cpuid_all(1,itask)
         en=cpuid_all(num_thr,itask)
         if(num_thr.eq.1) stride=0
         if(num_thr.gt.1) stride=(en-st)/(num_thr-1)
         write(61,"(i6,2x,2i6,2x,i6,2x,i6,a20)")itask-1,st,en,stride,&
            gpuid_all(itask),nodename_all(itask)
      end do
      close(61)
   end if

return
end
