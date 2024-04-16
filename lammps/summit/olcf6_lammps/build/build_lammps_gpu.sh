#!/bin/bash

echo "Setting up environment..."
source ../common_files/environment/setup_env_gpu.sh

echo
echo "Loaded modules:"
module list

# Sets compiler that the NVCC wrapper uses for host code & linking
export NVCC_WRAPPER_DEFAULT_COMPILER="$(which g++)"
# Validate exactly which compiler is being used:
export NVCC_WRAPPER_SHOW_COMMANDS_BEING_RUN=1

if [ ! -d ./lammps ]; then
    tar -xf ../lammps_08498637aa.tar.gz
fi

echo "Copying Makefile.summit_gpu..."
cp ./makefiles/Makefile.summit_gpu ./lammps/src/MAKE/MINE

echo "Changing directory to $(realpath ./lammps/src)..."
cd lammps/src

echo "Running clean-all..."
make clean-all

echo "Uninstalling all packages..."
make no-all

echo "Installing selected packages..."
for package in kokkos kspace molecule reaxff rigid; do
    make yes-$package
done

echo "Running 'make -j 8 summit_gpu'..."
make -j 8 summit_gpu
build_exit=$?
echo "Build complete. Exit code: ${build_exit}"

# Optional: mimic the structure of a CMake install
if [ -f lmp_summit_gpu ]; then
    if [ -d ../install-gpu ]; then
        echo "Removing existing GPU installation..."
        rm -rf ../install-gpu
    fi
    mkdir -p ../install-gpu/bin
    echo "Copying binary to $(realpath ../install-gpu/bin)..."
    mv ./lmp_summit_gpu ../install-gpu/bin/lmp
fi

# Clean up -- allows a CMake build to run without issue
make clean-all
make no-all
echo "Build completed with exit_code ${build_exit}"
