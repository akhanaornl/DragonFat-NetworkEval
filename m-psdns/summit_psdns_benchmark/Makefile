# set compilers
FC=mpif90
#FC=xlcuf

# set linker
LD=mpif90
#LD=xlcuf

# set flags
FFLAGS=-O3 -qarch=pwr9 -qtune=pwr9 -qtgtarch=sm_70 #-g -Rb

OPENMP_FLAG=-qsmp=omp -qoffload -qcuda

LDFLAGS=-L$(OLCF_CUDA_ROOT)/lib64

FDEFINES=

OBJS = procinfo.o MPI_A2A.o
EXE = MPI_A2A.x

%.o: %.F90
	$(FC) -c $< $(FFLAGS) $(OPENMP_FLAG) -o $@

$(EXE): $(OBJS)
	$(LD) $(OBJS) $(OPENMP_FLAG) $(LDFLAGS) -o $@

clean:
	rm -f *.o *.mod *.s *~

realclean:
	make clean
	rm -f $(EXE)

