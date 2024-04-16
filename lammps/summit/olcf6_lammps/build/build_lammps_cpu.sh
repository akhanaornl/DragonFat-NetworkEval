#!/bin/bash

echo "Setting up environment..."
source ../common_files/environment/setup_env_cpu.sh

echo
echo "Loaded modules:"
module list

if [ ! -d ./lammps ]; then
    tar -xf ../lammps_08498637aa.tar.gz
fi

echo "Copying Makefile.summit_cpu..."
cp ./makefiles/Makefile.summit_cpu ./lammps/src/MAKE/MINE

echo "Changing directory to $(realpath ./lammps/src)..."
cd lammps/src

echo "Running clean-all..."
make clean-all

echo "Uninstalling all packages..."
make no-all

echo "Installing selected packages..."
for package in kspace molecule openmp reaxff rigid; do
    make yes-$package
done

echo "Running 'make -j 8 summit_cpu'..."
make -j 8 summit_cpu
build_exit=$?
echo "Build complete. Exit code: ${build_exit}"

# Optional: mimic the structure of a CMake install
if [ -f lmp_summit_cpu ]; then
    if [ -d ../install-cpu ]; then
        echo "Removing existing CPU installation..."
        rm -rf ../install-cpu
    fi
    mkdir -p ../install-cpu/bin
    echo "Copying binary to $(realpath ../install-cpu/bin)..."
    mv ./lmp_summit_cpu ../install-cpu/bin/lmp
fi

make clean-all
make no-all
echo "Build completed with exit code: ${build_exit}"
