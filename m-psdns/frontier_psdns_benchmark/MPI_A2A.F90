program MPI_A2A

   use mpi
   use omp_lib
   implicit none
 
   integer :: nx,ny,nz,nv,nxh
   integer :: include_h2d_d2h = 0
   integer :: full_reporting = 0
   integer :: neglect_self_comm = 0
   integer :: xisz,zisz,zjsz,yisz,yjsz,nsteps
   complex, allocatable :: sndbuf_row(:,:,:,:,:), &
      rcvbuf1_row(:,:,:,:,:), rcvbuf2_row(:,:,:,:,:)
   complex, allocatable :: sndbuf_col(:,:,:,:,:), &
      rcvbuf1_col(:,:,:,:,:), rcvbuf2_col(:,:,:,:,:)
   integer :: i,j,x,y,z,xg,zg,yg,x1,z1,y1,ivar,istep
   integer :: numtasks,taskid,ipid,jpid,ierr,mpierr,iproc,jproc
   integer :: MPI_COMM_ROW,MPI_COMM_COL
   integer :: isendbuf(8)
   integer :: tasks_per_node
   integer :: num_on_node_row, num_network_row
   integer :: num_on_node_col, num_network_col
   real(kind=8) :: total_array_size,entry_size
   real(kind=8) :: total_row_comm_rate, total_col_comm_rate
   real(kind=8) :: on_node_row_comm_rate, on_node_col_comm_rate
   real(kind=8) :: network_row_comm_rate, network_col_comm_rate
   real :: err(4), errmax(4)
   real(kind=8) :: rtime1,rtime2,rtemp,time(6), &
                   msgsize(4),avgtime, cpt1, cpt2, cpt3, cptime(3)
   real(kind=8), allocatable :: time_step(:,:),time_all(:,:),cp_time_step(:,:),cp_time_all(:,:)

   call MPI_INIT (ierr)

   call MPI_COMM_SIZE (MPI_COMM_WORLD,numtasks,ierr)
   call MPI_COMM_RANK (MPI_COMM_WORLD,taskid,ierr)

   !!!!!!!!! read input and communicate to all processes !!!!!!!!!!

   !! Mimics the 2D decomposition and the communication patterns
   !! of the PSDNS family of codes

   !! nx,ny,nz       : number of points in each coordinate direction
   !!                : nx MUST be evenly divisible by (2*iproc)
   !!                : ny MUST be evenly dvisible by iproc and by jproc (not iproc*jproc)
   !!                : nz MUST be evenly dvisible by iproc and by jproc (not iproc*jproc)
   !!
   !! nv             : number of variables to pass
   !!
   !! iproc, jproc   : dimensions for the 2D domain decomposition 
   !!                : iproc*jproc = numtasks is REQUIRED
   !!                : iproc <= jproc is REQUIRED
   !!                : these values influence the choice of nx, ny, and nz
   !!
   !! tasks_per_node : number of mpi ranks per node
   !!
   !! The MPI communications are broken into "row" communications and "col" 
   !! communications dictated by the choice of iproc and jproc
   !! 
   !! There will be "jproc" row communicators and each row communicator will
   !! contain "iproc" mpi ranks.
   !! 
   !! There will be "iproc" col communicators and each col communicator will
   !! contain "jproc" mpi ranks.

   if (taskid .eq. 0) then
      open (111,file='input')

      read (111,fmt='(1x)')
      read (111,*) nx, ny, nz, nv

      read (111,fmt='(1x)')
      read (111,*) iproc, jproc

      read (111,fmt='(1x)')
      read (111,*) nsteps

      read (111,fmt='(1x)')
      read (111,*) tasks_per_node

      if (iproc .gt. jproc) then
         i = iproc
         iproc = jproc
         jproc = i
      endif

      i = iproc*jproc
      if (i .ne. numtasks) then
         write(6,*)" "
         write(6,"('PROBLEM: Invalid values for MPI')")
         write(6,"('         Requirement: iproc*jproc = numtasks')")
         write(6,"('         Attempting to correct with iproc = 2 and jproc = numtasks/2')")
         write(6,*)" "
         iproc = 2
         jproc = numtasks/2
      endif

      !! final check
      i = iproc*jproc
      if (i .ne. numtasks) then
         write(6,"('ERROR:   Unable to auto-correct iproc and jproc')")
         write(6,"('         Update input file with correct values: iproc*jproc = numtasks')")
         write(6,"('         ABORTING job')")
         write(6,*)" "
         call MPI_ABORT (MPI_COMM_WORLD, mpierr, ierr)
      endif

   end if

   call MPI_BARRIER (MPI_COMM_WORLD, ierr)
   
   isendbuf(1)=nx
   isendbuf(2)=ny
   isendbuf(3)=nz
   isendbuf(4)=nv
   isendbuf(5)=iproc
   isendbuf(6)=jproc
   isendbuf(7)=nsteps
   isendbuf(8)=tasks_per_node
   call MPI_BCAST (isendbuf,8,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
   nx=isendbuf(1)
   ny=isendbuf(2)
   nz=isendbuf(3)
   nv=isendbuf(4)
   iproc=isendbuf(5)
   jproc=isendbuf(6)
   nsteps=isendbuf(7)
   tasks_per_node=isendbuf(8)

   nxh=nx/2
   xisz=nxh/iproc
   zisz=nz/iproc
   zjsz=nz/jproc
   yisz=ny/iproc
   yjsz=ny/jproc

   if((taskid .eq. 0) .and. (full_reporting .eq. 1)) then
      write(6,*) "  "
      write(6,"('nsteps,numtasks,iproc,jproc : ',4i6)") nsteps, numtasks, iproc, jproc
      write(6,"('nx,ny,nz,nv,nxh             : ',5i6)") nx, ny, nz, nv, nxh
      write(6,"('xisz,zisz,zjsz,yisz,yjsz    : ',5i6)") xisz, zisz, zjsz, yisz, yjsz
      write(6,*) "  "
   endif

   !! Set up 2D decomposition processor layout !!!!!!
   jpid=taskid/iproc
   ipid=mod(taskid,iproc)
   
   call MPI_COMM_SPLIT (MPI_COMM_WORLD, jpid, taskid, &
      MPI_COMM_ROW, ierr)

   call MPI_COMM_SPLIT (MPI_COMM_WORLD, ipid, taskid, &
      MPI_COMM_COL, ierr)

   !! write processor layout !!!!!!!
   !write (6,*) "taskid,ipid,jpid=",taskid,ipid,jpid

   call MPI_BARRIER (MPI_COMM_WORLD, ierr)

   !! uncomment this to get details about the nodes
   !call procinfo

   !! set up details for the B/W calculations
   !! set num_on_node_row
   num_on_node_row = min(iproc, tasks_per_node)
   !! separate on_node from across_network for row comms
   num_network_row = iproc - num_on_node_row
   !! set num_on_node_col
   num_on_node_col = min(jproc, (tasks_per_node/num_on_node_row))
   !! separate on_node from across_network for col comms
   num_network_col = jproc - num_on_node_col

   !! error check for neglect_self_comm
   !! include self-communication in B/W with neglect_self_comm = 0
   !! neglect self-communication in B/W with neglect_self_comm = 1
   if (neglect_self_comm .lt. 0) neglect_self_comm = 0
   if (neglect_self_comm .gt. 1) neglect_self_comm = 1
  
   if (taskid .eq. 0) then
      write(6,*)" "
      write(6,"('MPI tasks_per_node =',i3)") tasks_per_node
      write(6,"('MPI Row Comms : Number On-Node        =',i6)") num_on_node_row
      write(6,"('MPI Row Comms : Number Across Network =',i6)") num_network_row
      write(6,"('MPI Col Comms : Number On-Node        =',i6)") num_on_node_col
      write(6,"('MPI Col Comms : Number Across Network =',i6)") num_network_col
      write(6,*)" "
      if (neglect_self_comm .eq. 0) then
         write(6,"('Including self-communication in the B/W calculations')")
      else
         write(6,"('Neglecting self-communication in the B/W calculations')")
      endif
      write(6,*)" "
   endif

   !!!!!!!! allocate arrays !!!!!!!!
   !! NOTE: we could do a single large array for the send buffers
   !!       the receive buffers and use it for both the row and 
   !!       column communications instead of having separate 
   !!       row and column buffers ... this would cut the memory 
   !!       requirement in half to use larger messages
   allocate (sndbuf_row(xisz,yisz,zjsz,nv,iproc))
   allocate (sndbuf_col(xisz,yjsz,zjsz,nv,jproc))
   allocate (rcvbuf1_row(xisz,yisz,zjsz,nv,iproc))
   allocate (rcvbuf1_col(xisz,yjsz,zjsz,nv,jproc))
   allocate (rcvbuf2_row(xisz,yisz,zjsz,nv,iproc))
   allocate (rcvbuf2_col(xisz,yjsz,zjsz,nv,jproc))

   !! these are complex arrays (e.g. each entry is 8 Bytes long) and 
   !! I'm including the factor to convert from Bytes to MB
   entry_size = 8.d0/1024.d0/1024.d0

   !! message sizes in MB (these are complex arrays)
   !! NOTE: go ahead and explicitly convert the ints to reals to avoid
   !!       compiler issues with automatic promotion and/or issues with 
   !!       exceeding the limit of 32 bit int arithmetic
   !! for row : (1) total and (2) P2P
   msgsize(1)=entry_size*dble(xisz)*dble(yisz)*dble(zjsz)*dble(nv)*dble(iproc)
   msgsize(2)=entry_size*dble(xisz)*dble(yisz)*dble(zjsz)*dble(nv)
   !! for column : (3) total and (4) P2P
   msgsize(3)=entry_size*dble(xisz)*dble(yjsz)*dble(zjsz)*dble(nv)*dble(jproc)
   msgsize(4)=entry_size*dble(xisz)*dble(yjsz)*dble(zjsz)*dble(nv)

   !! allocating 6 complex arrays on cpu and gpu
   !! NOTE: converting to GB to report total array size
   total_array_size = (3*msgsize(1) + 3*msgsize(3))/1024.0

   !! allocate arrays
   if (taskid.eq.0) then
      write(6,"('Each MPI rank is allocating ',f6.2,' GB on both the CPUs and GPUs')") total_array_size
      write(6,*) "  "
   endif

   allocate(time_step(nsteps,6))
   allocate(time_all(6,numtasks))
   allocate(cp_time_step(nsteps,3))
   allocate(cp_time_all(3,numtasks))

   !!!!!!!!!!!!!!!!!!!!!!!!!!!!! MPI-ALLTOALL !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   !!!!!!!!! Initialise arrays !!!!!!!!

   time_step(:,:)=0.
   cp_time_step(:,:)=0.

   rcvbuf1_row(:,:,:,:,:)=0.
   rcvbuf1_col(:,:,:,:,:)=0.
   rcvbuf2_row(:,:,:,:,:)=0.
   rcvbuf2_col(:,:,:,:,:)=0.

   ! For row communicator alltoall

   do xg=1,iproc
      do ivar=1,nv
         do z=1,zjsz
            z1=jpid*zjsz+z
            do y=1,yisz
               y1=ipid*yisz+y
               do x=1,xisz
                  x1=(xg-1)*xisz+x
                  sndbuf_row(x,y,z,ivar,xg)=&
                     100.*x1+10.*y1+1.*z1+0.1*ivar
               end do
            end do
         end do
      end do
   end do
   
   ! For column communicator alltoall
   do yg=1,jproc
      do ivar=1,nv
         do z=1,zjsz
            z1=jpid*zjsz+z
            do y=1,yjsz
               y1=(yg-1)*yjsz+y
               do x=1,xisz
                  x1=ipid*xisz+x
                  sndbuf_col(x,y,z,ivar,yg)=&
                     100.*x1+10.*y1+1.*z1+0.1*ivar
               end do
            end do
         end do
      end do
   end do

   !! NOTE: Since we compute on the GPUs, we want to compare
   !!       the entire process of GPU-Direct MPI comms and 
   !!       CPU MPI comms (which include the additional task
   !!       of copying the data to/from the GPU)

   !!!!!!!! start the target data region !!!!!!!

   !$OMP TARGET DATA MAP(to:sndbuf_row, sndbuf_col) &
   !$OMP             MAP(from:rcvbuf2_row, rcvbuf2_col) &
   !$OMP             MAP(alloc:rcvbuf1_row, rcvbuf1_col)

   !!!!!!!! Perform the Alltoall using CPU buffers !!!!!!!
   do istep=1,nsteps

      call MPI_BARRIER(MPI_COMM_WORLD,ierr)

      !! for total mpi time
      rtemp=MPI_WTIME()

      ! row communicator

      ! update cpu version
      if (include_h2d_d2h .eq. 1) then 
          cpt1 = MPI_WTIME()
          !$OMP TARGET UPDATE FROM(sndbuf_row)
          cpt2 = MPI_WTIME() - cpt1
      endif

      rtime1=MPI_WTIME()
      call MPI_ALLTOALL(sndbuf_row, xisz*yisz*zjsz*nv, MPI_COMPLEX, &
         rcvbuf1_row, xisz*yisz*zjsz*nv, MPI_COMPLEX, &
         MPI_COMM_ROW, ierr)
      rtime2=MPI_WTIME()
      time_step(istep,1)=rtime2-rtime1

      ! update GPU version
      if (include_h2d_d2h .eq. 1) then 
          cpt1 = MPI_WTIME()
          !$OMP TARGET UPDATE TO(rcvbuf1_row)
          cp_time_step(istep,1) = cpt2 + (MPI_WTIME() - cpt1)
      endif
         
      ! column communicator

      ! update cpu version
      if (include_h2d_d2h .eq. 1) then 
          cpt1 = MPI_WTIME()
          !$OMP TARGET UPDATE FROM(sndbuf_col)
          cpt2 = MPI_WTIME() - cpt1
      endif

      rtime1=MPI_WTIME()
      call MPI_ALLTOALL(sndbuf_col, xisz*yjsz*zjsz*nv, MPI_COMPLEX, &
         rcvbuf1_col, xisz*yjsz*zjsz*nv, MPI_COMPLEX, &
         MPI_COMM_COL, ierr)
      rtime2=MPI_WTIME()
      time_step(istep,2)=rtime2-rtime1

      ! update GPU version
      if (include_h2d_d2h .eq. 1) then 
          cpt1 = MPI_WTIME()
          !$OMP TARGET UPDATE TO(rcvbuf1_col)
          cp_time_step(istep,2) = cpt2 + (MPI_WTIME() - cpt1)

          cp_time_step(istep,3) = cp_time_step(istep,1) + cp_time_step(istep,2)
      endif

      !! total comm time
      time_step(istep,3)=MPI_WTIME()-rtemp
    end do

   !!!!!!!! Perform the Alltoall using GPU buffers !!!!!!!

   do istep=1,nsteps

      call MPI_BARRIER(MPI_COMM_WORLD,ierr)
         
      rtemp=MPI_WTIME()
      rtime1=MPI_WTIME()
      !$OMP TARGET DATA USE_DEVICE_PTR(sndbuf_row,rcvbuf2_row)
      call MPI_ALLTOALL(sndbuf_row, xisz*yisz*zjsz*nv, MPI_COMPLEX, &
         rcvbuf2_row, xisz*yisz*zjsz*nv, MPI_COMPLEX, &
         MPI_COMM_ROW, ierr)
      !$OMP END TARGET DATA
      rtime2=MPI_WTIME()
      time_step(istep,4)=rtime2-rtime1
         
      rtime1=MPI_WTIME()
      !$OMP TARGET DATA USE_DEVICE_PTR(sndbuf_col,rcvbuf2_col)
      call MPI_ALLTOALL(sndbuf_col, xisz*yjsz*zjsz*nv, MPI_COMPLEX, &
         rcvbuf2_col, xisz*yjsz*zjsz*nv, MPI_COMPLEX, &
         MPI_COMM_COL, ierr)
      !$OMP END TARGET DATA
      rtime2=MPI_WTIME()
      time_step(istep,5)=rtime2-rtime1
         
      !! total comm time
      time_step(istep,6)=rtime2-rtemp

   end do

   !!!!!!!!! end the target data region
   !$OMP END TARGET DATA

   !!!!!!!!! Check the results !!!!!!!!
   
   ! For row communicator alltoall

   do yg=1,iproc
      do ivar=1,nv
         do z=1,zjsz
            z1=jpid*zjsz+z
            do y=1,yisz
               y1=(yg-1)*yisz+y
               do x=1,xisz
                  x1=ipid*xisz+x
                  rcvbuf1_row(x,y,z,ivar,yg) = &
                     rcvbuf1_row(x,y,z,ivar,yg) - &
                     (100.*x1+10.*y1+1.*z1+0.1*ivar)
                  rcvbuf2_row(x,y,z,ivar,yg) = &
                     rcvbuf2_row(x,y,z,ivar,yg) - &
                     (100.*x1+10.*y1+1.*z1+0.1*ivar)
               end do
            end do
         end do
      end do
   end do
   
   ! For column communicator alltoall
   do zg=1,jproc
      do ivar=1,nv
         do z=1,zjsz
            z1=(zg-1)*zjsz+z
            do y=1,yjsz
               y1=jpid*yjsz+y
               do x=1,xisz
                  x1=ipid*xisz+x
                  rcvbuf1_col(x,y,z,ivar,zg) = &
                     rcvbuf1_col(x,y,z,ivar,zg) - &
                     (100.*x1+10.*y1+1.*z1+0.1*ivar)
                  rcvbuf2_col(x,y,z,ivar,zg) = &
                     rcvbuf2_col(x,y,z,ivar,zg) - &
                     (100.*x1+10.*y1+1.*z1+0.1*ivar)
               end do
            end do
         end do
      end do
   end do

   err(1)=maxval(abs(rcvbuf1_row))
   err(2)=maxval(abs(rcvbuf1_col))
   err(3)=maxval(abs(rcvbuf2_row))
   err(4)=maxval(abs(rcvbuf2_col))
   call MPI_ALLREDUCE(err,errmax,4,MPI_REAL,MPI_MAX, &
      MPI_COMM_WORLD,ierr)

      !!!!!! Print the errors !!!!!!!!

   if (taskid.eq.0) then
      write(6,*) "  "
      if (abs(errmax(1)) .gt. 1.0e-8) then
         write(6,"('Row: Max Global Error (MPI-A2A CPU) :',1p,e12.4)") errmax(1)
      endif
      if (abs(errmax(2)) .gt. 1.0e-8) then
         write(6,"('Col: Max Global Error (MPI-A2A CPU) :',1p,e12.4)") errmax(2)
      endif
      if (abs(errmax(3)) .gt. 1.0e-8) then
         write(6,"('Row: Max Global Error (MPI-A2A GPU) :',1p,e12.4)") errmax(3)
      endif
      if (abs(errmax(4)) .gt. 1.0e-8) then
         write(6,"('Col: Max Global Error (MPI-A2A GPU) :',1p,e12.4)") errmax(4)
      endif
      write(6,*) "  "
   endif

   !!!!!!! Collect timings and errors from all tasks !!!!!!!!!

   time(1)=(sum(time_step(:,1))-time_step(1,1))/(nsteps-1)
   time(2)=(sum(time_step(:,2))-time_step(1,2))/(nsteps-1)
   time(3)=(sum(time_step(:,3))-time_step(1,3))/(nsteps-1)
   time(4)=(sum(time_step(:,4))-time_step(1,4))/(nsteps-1)
   time(5)=(sum(time_step(:,5))-time_step(1,5))/(nsteps-1)
   time(6)=(sum(time_step(:,6))-time_step(1,6))/(nsteps-1)
   call MPI_GATHER(time,6,MPI_REAL8,time_all,6,MPI_REAL8, &
      0,MPI_COMM_WORLD,ierr)

   if (include_h2d_d2h .eq. 1) then 
       cptime(1)=(sum(cp_time_step(:,1))-cp_time_step(1,1))/(nsteps-1)
       cptime(2)=(sum(cp_time_step(:,2))-cp_time_step(1,2))/(nsteps-1)
       cptime(3)=(sum(cp_time_step(:,3))-cp_time_step(1,3))/(nsteps-1)
       call MPI_GATHER(cptime,3,MPI_REAL8,cp_time_all,3,MPI_REAL8, &
          0,MPI_COMM_WORLD,ierr)
   endif

   !!!!!! Print the timings !!!!!!!!

   if (taskid.eq.0) then
      !! Message sizes for the communications
      write(6,*) "  "
      write(6,"('Row: Total Message size (MB) :',f12.5)") msgsize(1)
      write(6,"('Row: P2P Message size (MB)   :',f12.5)") msgsize(2)
      write(6,"('Col: Total Message size (MB) :',f12.5)") msgsize(3)
      write(6,"('Col: P2P Message size (MB)   :',f12.5)") msgsize(4)
      write(6,*) "  "
      write(6,*) "  "

      write(6,"('Process for time-averaging across all the mpi ranks:')")
      write(6,"('(1) the timings for each mpi rank are averaged over',i3)") (nsteps - 1)
      write(6,"('    timesteps to get an average runtime for each rank')")
      write(6,*) "  "
      write(6,"('(2) these time-averaged runtimes are averaged across the')")
      write(6,"('    mpi ranks to find the average runtime for the ranks')")
      write(6,*) "  "
      write(6,*) "  "

      !! CPU timings
      avgtime=(sum(time_all(1,:))/numtasks)
      write(6,"('Row- CPU MPI-ALLTOALL          :',1p,e12.4)") avgtime

      !! compute the data transfer rate
      !! (1) remove the data owned by the rank that simply needs to be 
      !!     copied from send buffer to receive buffer
      !! (2) convert from MB to GB
      !! (3) factor of 2 accounts for both the send and recv
      total_row_comm_rate = 2.d0*(msgsize(1) - dble(neglect_self_comm)*msgsize(2))/avgtime/1024.d0
      
      !! separate the comm rates between on-node and across-network rates
      !! NOTE: remove the self-communication from the on-node rate
      on_node_row_comm_rate = 2.d0*(dble(num_on_node_row - neglect_self_comm)*msgsize(2))/avgtime/1024.d0
      network_row_comm_rate = 2.d0*(dble(num_network_row)*msgsize(2))/avgtime/1024.d0

      avgtime=(sum(time_all(2,:))/numtasks)
      write(6,"('Col- CPU MPI-ALLTOALL          :',1p,e12.4)") avgtime

      !! compute the data transfer rate
      !! (1) remove the data owned by the rank that simply needs to be 
      !!     copied from send buffer to receive buffer
      !! (2) convert from MB to GB
      !! (3) factor of 2 accounts for both the send and recv
      total_col_comm_rate = 2.d0*(msgsize(3) - dble(neglect_self_comm)*msgsize(4))/avgtime/1024.d0

      !! separate the comm rates between on-node and across-network rates
      !! NOTE: remove the self-communication from the on-node rate
      on_node_col_comm_rate = 2.d0*(dble(num_on_node_col - neglect_self_comm)*msgsize(4))/avgtime/1024.d0
      network_col_comm_rate = 2.d0*(dble(num_network_col)*msgsize(4))/avgtime/1024.d0
      
      if (include_h2d_d2h .eq. 1) then 
          avgtime=(sum(cp_time_all(1,:))/numtasks)
          write(6,"('Row- Host-Device-Copy Time     :',1p,e12.4)") avgtime
          avgtime=(sum(cp_time_all(2,:))/numtasks)
          write(6,"('Col- Host-Device-Copy Time     :',1p,e12.4)") avgtime
      endif
      write(6,*) "-------------------------------------------------------"
      if (include_h2d_d2h .eq. 1) then 
          avgtime=(sum(cp_time_all(3,:))/numtasks)
          write(6,"('Total CPU H2D and D2H Time     :',1p,e12.4)") avgtime
          avgtime = (sum(time_all(3,:))/numtasks) - (sum(cp_time_all(3,:))/numtasks)
          write(6,"('Total CPU Communication Time   :',1p,e12.4)") avgtime
          write(6,*) "-------------------------------------------------------"
      endif
      avgtime=(sum(time_all(3,:))/numtasks)
      write(6,"('Overall CPU Time               :',1p,e12.4)") avgtime
      write(6,*) "  "
      
      write(6,"('CPU MPI Row Comm Rate per MPI Rank')") 
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_row_comm_rate
      write(6,"('    Network (GB/sec) : ',f12.4)") network_row_comm_rate
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_row_comm_rate
      write(6,*) "  "
      write(6,"('CPU MPI Col Comm Rate per MPI Rank')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_col_comm_rate
      write(6,"('    Network (GB/sec) : ',f12.4)") network_col_comm_rate
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_col_comm_rate
      write(6,*) "  "
      write(6,*) "  "
      write(6,"('CPU MPI Row Comm Rate per Node')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_row_comm_rate*dble(tasks_per_node)
      write(6,"('    Network (GB/sec) : ',f12.4)") network_row_comm_rate*dble(tasks_per_node)
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_row_comm_rate*dble(tasks_per_node)
      write(6,*) "  "
      write(6,"('CPU MPI Col Comm Rate per Node')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_col_comm_rate*dble(tasks_per_node)
      write(6,"('    Network (GB/sec) : ',f12.4)") network_col_comm_rate*dble(tasks_per_node)
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_col_comm_rate*dble(tasks_per_node)
      write(6,*) "  "
      write(6,*) "  "

      

      !! GPU timings
      avgtime=(sum(time_all(4,:))/numtasks)
      write(6,"('Row- GPU MPI-ALLTOALL  :',1p,e12.4)") avgtime

      !! compute the data transfer rate
      !! (1) remove the data owned by the rank that simply needs to be 
      !!     copied from send buffer to receive buffer
      !! (2) convert from MB to GB
      !! (3) factor of 2 accounts for both the send and recv
      total_row_comm_rate = 2.d0*(msgsize(1) - dble(neglect_self_comm)*msgsize(2))/avgtime/1024.d0

      !! separate the comm rates between on-node and across-network rates
      !! NOTE: remove the self-communication from the on-node rate
      on_node_row_comm_rate = 2.d0*(dble(num_on_node_row - neglect_self_comm)*msgsize(2))/avgtime/1024.d0
      network_row_comm_rate = 2.d0*(dble(num_network_row)*msgsize(2))/avgtime/1024.d0

      avgtime=(sum(time_all(5,:))/numtasks)
      write(6,"('Col- GPU MPI-ALLTOALL  :',1p,e12.4)") avgtime

      !! compute the data transfer rate
      !! (1) remove the data owned by the rank that simply needs to be 
      !!     copied from send buffer to receive buffer
      !! (2) convert from MB to GB
      !! (3) factor of 2 accounts for both the send and recv
      total_col_comm_rate = 2.d0*(msgsize(3) - dble(neglect_self_comm)*msgsize(4))/avgtime/1024.d0

      !! separate the comm rates between on-node and across-network rates
      !! NOTE: remove the self-communication from the on-node rate
      on_node_col_comm_rate = 2.d0*(dble(num_on_node_col - neglect_self_comm)*msgsize(4))/avgtime/1024.d0
      network_col_comm_rate = 2.d0*(dble(num_network_col)*msgsize(4))/avgtime/1024.d0

      write(6,*) "---------------------------------------------------"
      avgtime=(sum(time_all(6,:))/numtasks)
      write(6,"('Overall GPU Time       :',1p,e12.4)") avgtime
      write(6,*) "  "
      
      write(6,"('GPU MPI Row Comm Rate per MPI Rank')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_row_comm_rate
      write(6,"('    Network (GB/sec) : ',f12.4)") network_row_comm_rate
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_row_comm_rate
      write(6,*) "  "
      write(6,"('GPU MPI Col Comm Rate per MPI Rank')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_col_comm_rate
      write(6,"('    Network (GB/sec) : ',f12.4)") network_col_comm_rate
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_col_comm_rate
      write(6,*) "  "
      write(6,*) "  "
      write(6,"('GPU MPI Row Comm Rate per Node')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_row_comm_rate*dble(tasks_per_node)
      write(6,"('    Network (GB/sec) : ',f12.4)") network_row_comm_rate*dble(tasks_per_node)
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_row_comm_rate*dble(tasks_per_node)
      write(6,*) "  "
      write(6,"('GPU MPI Col Comm Rate per Node')")
      write(6,"('    On-node (GB/sec) : ',f12.4)") on_node_col_comm_rate*dble(tasks_per_node)
      write(6,"('    Network (GB/sec) : ',f12.4)") network_col_comm_rate*dble(tasks_per_node)
      write(6,"('    Total   (GB/sec) : ',f12.4)") total_col_comm_rate*dble(tasks_per_node)
      write(6,*) "  "
      write(6,*) "  "

   end if

   call MPI_BARRIER(MPI_COMM_WORLD,ierr)
   call MPI_FINALIZE (ierr)

end
