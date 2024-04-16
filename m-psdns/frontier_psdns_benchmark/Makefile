GPU_PATH=${OLCF_ROCM_ROOT}

GPU_INCLUDE_PATH=${GPU_PATH}/include
GPU_LIB_PATH=${GPU_PATH}/lib

INCLUDE_PATH=-I$(GPU_INCLUDE_PATH)

# set compilers
FC=ftn

# set linker
LD=ftn

# set flags
FFLAGS = -I. -O3 -N132 -hacc_model=no_fast_addr -hacc_model=auto_async_none -hflex_mp=strict -hfp2=noapprox
## for debugging with optimization
#FFLAGS = -I. -G2 -N132 -hacc_model=no_fast_addr -hacc_model=auto_async_none -hflex_mp=strict -hfp2=noapprox
#FFLAGS += -eo
FFLAGS += -target-accel=amd_gfx90a 

OPENMP_FLAG=-homp

LDFLAGS=-L$(GPU_LIB_PATH) -L. -lstdc++ -lm

FDEFINES=

OBJS=MPI_A2A.o procinfo.o
EXE=MPI_A2A.x

%.o: %.F90
	$(FC) -craype-verbose -c $< $(FDEFINES) $(FFLAGS) $(CPPFLAGS) $(OPENMP_FLAG) -o $@ $(INCLUDE_PATH)

$(EXE) : $(OBJS)
	$(LD) $(OBJS) $(OPENMP_FLAG) $(LDFLAGS) -o $@

clean:
	rm -f *.o *.mod *.s *~

realclean:
	make clean
	rm -f $(EXE)

