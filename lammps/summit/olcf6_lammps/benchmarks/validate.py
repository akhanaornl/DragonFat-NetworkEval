#!/usr/bin/env python3

import argparse
import os
import re

parser = argparse.ArgumentParser(description="Validation script for LAMMPS.")
parser.add_argument('--input', '-i', type=str, default='.', action='store', required=True, help="Relative or absolute path of directory to search for LAMMPS log files.")
parser.add_argument('--rfp', type=str, action='store', required=True, help="Path of the correct LAMMPS log file.")
parser.add_argument('--quiet', default=False, action='store_true', help="If True, only prints the SUCCESS/FAIL message at the end.")
parser.add_argument('--threshold', type=float, default=0.1, action='store', help="Percentage difference tolerated in energy breakdown.")
parser.add_argument('--exclude_field', type=str, default=['Pxx', 'Pyy', 'Pzz'], action='append', help="Add a field name to ignore when validating runs. For example, 'Pxx'")

args = parser.parse_args()

def check_file(f):
    """ Checks for completeness of LAMMPS output """
    found_header_line = False
    found_performance_line = False
    found_walltime_line = False
    reached_run = False
    completed_run = False
    with open(f, 'r') as f_in:
        for line in f_in:
            if line.strip() == 'LAMMPS (23 Jun 2022 - Update 4)':
                found_header_line = True
            elif found_header_line and line.startswith("Performance:"):
                found_performance_line = True
            elif found_header_line and line.startswith("Loop time of"):
                completed_run = True
            elif found_header_line and found_performance_line and completed_run and line.startswith("Total wall time"):
                found_walltime_line = True
            # If there is a failure in the middle of the simulation, try to capture it
            if found_header_line and (not reached_run) and line.strip().startswith("Step"):
                reached_run = True
            elif found_header_line and reached_run and line.strip().startswith("Loop time"):
                completed_run = True
            elif found_header_line and reached_run and not completed_run:
                # Then it should be numerical lines
                line_splt = line.strip().split()
                are_numerical = [e.replace('.', '', 1).isnumeric() for e in line_splt]
                if False in are_numerical:
                    return ['FAIL', f'Detected line that should contain integers, contained strings: {line}']
    if not found_header_line:
        print(f"LAMMPS header line never found. It does not look like the LAMMPS run started.")
        return False
    if not completed_run:
        print(f"LAMMPS run did not fully complete.")
        return False
    if not found_walltime_line:
        print(f"LAMMPS failed after completing the simulation, but before printing the walltime.")
        return False
    return True

def energy_breakdown(f_rfp, f_input):
    print(f"Checking energy breakdown. Ignoring the following fields: {', '.join(args.exclude_field)}")
    file1 = open(f_rfp, 'r')
    file2 = open(f_input, 'r')
    sim1 = {}
    sim2 = {}

    def check_step(sim1, sim2):
        correct = True
        for key in sim1.keys():
            if not key == 'Step':
                ratio = abs((sim1[key] - sim2[key]) / sim1[key]) * 100
                # 0.1% difference in energy breakdown
                if ratio > args.threshold:
                    if not args.quiet:
                        print(f"Key: {key}, ref: {sim1[key]}, calculated: {sim2[key]}, percentage diff: {ratio}")
                    correct = False
        return correct

    for line in file1:
        if line.find("Step") > -1:
            labels = line.split()
            line = next(file1)
            index_ct = 0
            while not line.split()[0].strip() == 'Loop':
                sim1[index_ct] = {}
                line = line.split()
                for j in range(0, len(line)):
                    if not labels[j] in args.exclude_field:
                        sim1[index_ct][labels[j]] = float(line[j])
                line = next(file1)
                index_ct += 1
    for line in file2:
        if line.find("Step") > -1:
            labels = line.split()
            line = next(file2)
            index_ct = 0
            while not line.startswith('Loop'):
                sim2[index_ct] = {}
                line = line.split()
                for j in range(0, len(line)):
                    if not labels[j] in args.exclude_field:
                        sim2[index_ct][labels[j]] = float(line[j])
                line = next(file2)
                index_ct += 1
    if not len(sim1) == len(sim2):
        print(f"Simulations of different lengths found: {len(sim1)} != {len(sim2)}. Aborting energy breakdown check.")
        return False
    correct = True
    for i in range(0, len(sim1)):
        if not check_step(sim1[i], sim2[i]):
            print(f"check_step failed at step: {sim1[i]['Step']}. Energy breakdown failed.")
            correct = False
    return correct

# Returns perf_metric
def get_performance(f):
    """ Checks for graceful exits of LAMMPS runs """
    found_loop_time_line = False
    loop_time_line = ''
    with open(f, 'r') as f_in:
        for line in f_in:
            if line.startswith("Loop time of"):
                found_loop_time_line = True
                loop_time_line = line
    if not found_loop_time_line:
        if not args.quiet:
            print(f"Did not find loop time line. Run did not appear to complete gracefully.")
        return -1.0
    loop_time_line = loop_time_line.split()
    # natoms * steps /s
    atom_steps_per_sec = float(loop_time_line[11]) * float(loop_time_line[8]) / float(loop_time_line[3])
    return atom_steps_per_sec

# Check if both args.input and args.rfp are valid files
if not os.path.isfile(args.input):
    print("LAMMPS input file not found. Exiting.")
    exit(1)
elif not os.path.isfile(args.rfp):
    print("RFP file not found. Exiting.")
    exit(1)

if not args.quiet:
    print(f"Checking: {args.input} against {args.rfp} for correctness.")

check_result = check_file(f"{args.input}")
if not check_result:
    print("check_file failed, aborting check.")
    exit(1)
if not energy_breakdown(f"{args.rfp}", f"{args.input}"):
    print("Comparing energy breakdown failed, aborting check.")
    exit(1)
else:
    perf_metric = get_performance(f"{args.input}")
    if perf_metric < 0:
        print("Retrieving LAMMPS performance failed. Aborting")
        exit(1)
    print(f"LAMMPS run passed all validation with a FOM of {perf_metric} atom-steps/s")
