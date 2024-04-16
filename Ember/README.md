# EMBER - Halo3D-26 Frontier and Summit evaluation.

This folder contains the scripts and source code to reproduce the results on the An Evaluation of the Effect of Network Cost
Optimization for Leadership Class Supercomputers paper, in particular the Section VI.A.

The folder ``scripts`` contain the Slurm job scripts to run the three node placement strategies adopted in the paper; default, block and random. 
The scripts and graphs can be found the ``plots`` folder and ``scr`` contains the source code and Makefile to build the Halo3D-26 benchmark from a modified version
of Ember that includes GPU memory allocation for both HIP and CUDA.