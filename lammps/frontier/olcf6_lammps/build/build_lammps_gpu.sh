#!/bin/bash

echo "Setting up environment..."
source ../common_files/environment/setup_env_gpu.sh

echo
echo "Loaded modules:"
module list

if [ ! -d ./lammps ]; then
    # Commit 08498637aa from LAMMPS develop branch
    tar -xf ../lammps_08498637aa.tar.gz
fi

echo "Copying Makefile.frontier_gpu..."
cp ./makefiles/Makefile.frontier_gpu ./lammps/src/MAKE/MINE

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

echo "Running 'make -j 8 frontier_gpu'..."
make -j 8 frontier_gpu
build_exit=$?
echo "Build complete. Exit code: ${build_exit}"

# Optional: mimic the structure of a CMake install
if [ -f lmp_frontier_gpu ]; then
    if [ -d ../install-gpu ]; then
        echo "Removing existing GPU installation..."
        rm -rf ../install-gpu
    fi
    mkdir -p ../install-gpu/bin
    echo "Copying binary to $(realpath ../install-gpu/bin)..."
    mv ./lmp_frontier_gpu ../install-gpu/bin/lmp
fi

# Clean up -- allows a CMake build to run without issue
make clean-all
make no-all
echo "Build completed with exit_code ${build_exit}"
