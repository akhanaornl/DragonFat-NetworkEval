Flash-X Maclaurin Spheroid Artifact Description
============

Artifacts and instructions for reproducing results described for Flash-X Maclaurin Spheroid application

## Module environment (Lmod)

(For both building and running)

Frontier:
```
craype-x86-trento
libfabric/1.15.2.0
craype-network-ofi
perftools-base/22.12.0
xpmem/2.6.2-2.5_2.22__gd067c3f.shasta
cray-pmi/6.1.8
cce/15.0.0
craype/2.7.19
cray-dsmml/0.2.2
cray-mpich/8.1.23
cray-libsci/22.12.1.1
PrgEnv-cray/8.3.3
darshan-runtime/3.4.0
hsi/default
DefApps/default
cray-hdf5-parallel/1.12.2.1
```

Summit:
```
lsf-tools/2.0
hsi/5.0.2.p5
xalt/1.2.1
DefApps
gcc/12.1.0
essl/6.1.0-1
netlib-lapack/3.11.0
spectrum-mpi/10.4.0.6-20230210
hdf5/1.14.3
```

## Source code

Instructions for obtaining access to Flash-X source code at https://flash-x.org/pages/source-code/

Building executable:
```
# Clone and go to branch used
git clone -b jaharris/network_scaling git@github.com:Flash-X/Flash-X.git Flash-X
cd Flash-X

# Setup Maclaurin Spheroid problem to be compiled
./setup unitTest/Gravity/Poisson3 -auto -3d +cartesian -nxb=16 -nyb=16 -nzb=16 -objdir=Maclaurin +newMpole -maxblocks=1024 Bittree=True ImprovedSort=True AltMorton=True -defines=HAVE_MPI_MODULE +parallelIO timeMultipole=True

# Compile
cd Maclaurin
make -j16
```

## Running

Job scripts, parameter files, and generated output for all runs included in `frontier` and `summit` directories

## Plotting

Script for Flash-X scaling figure: `flashx_p_eff.py`
