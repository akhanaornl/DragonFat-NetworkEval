
CC=nvcc
CFLAGS=-O3 -g -D WITH_CUDA
LIBS=-L${OMPI_DIR}/lib -lmpi_ibm
INCLUDE=-I${OMPI_DIR}/include

HIP_CC=hipcc
HIP_CFLAGS=-O3 -g -D WITH_HIP -D__HIP_PLATFORM_AMD__
HIP_LIBS=-L${MPICH_DIR}/lib -lmpi ${CRAY_XPMEM_POST_LINK_OPTS} -lxpmem ${PE_MPICH_GTL_DIR_amd_gfx90a} ${PE_MPICH_GTL_LIBS_amd_gfx90a} 
HIP_INCL=-I${MPICH_DIR}/include

halo3d-26: halo3d-26.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS) $(INCLUDE)

halo3d-26_hip: halo3d-26.c
	$(HIP_CC) $(HIP_CFLAGS) -o $@ $< $(HIP_LIBS) $(HIP_INCL)

clean:
	rm -f halo3d-26
	rm -f halo3d-26_hip

