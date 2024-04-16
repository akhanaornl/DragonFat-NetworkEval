#!/usr/bin/env python3

import argparse
import os
import re

parser = argparse.ArgumentParser(description="Validation script for LAMMPS SPC/E problem.")
parser.add_argument('--input', '-i', type=str, default='.', action='store', required=True, help="Input LAMMPS log file.")
parser.add_argument('--quiet', default=False, action='store_true', help="If True, only prints the SUCCESS/FAIL message at the end.")

args = parser.parse_args()

def check_file(f):
    """ Checks for completeness of LAMMPS output """
    def is_numeric(s):
        """ Checks if an entry (RHS) is numeric """
        # Local function. s is assumed to be a whitespace-stripped string
        # Return false for empty string
        if len(s) == 0:
            return False
        number_regex = re.compile('^[-]?([0-9]*\.)?[0-9]+([eE]{1}[+-]?[0-9]+)?$')
        if number_regex.match(s):
            return True
        else:
            return False
    found_header_line = False
    found_performance_line = False
    found_walltime_line = False
    reached_run = False
    completed_run = False
    with open(f, 'r') as f_in:
        for line in f_in:
            if line.strip().startswith('LAMMPS ('):
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
                are_numerical = [is_numeric(e) for e in line_splt]
                if False in are_numerical:
                    if not args.quiet:
                        print(f"Detected line that should contain integers, contained strings: {line}")
                    return False
    if not found_header_line:
        if not args.quiet:
            print(f"LAMMPS header line never found. It does not look like the LAMMPS run started.")
        return False
    if not completed_run:
        if not args.quiet:
            print(f"LAMMPS run did not fully complete.")
        return False
    if not found_walltime_line:
        if not args.quiet:
            print(f"LAMMPS failed after completing the simulation, but before printing the walltime.")
        return False
    return True

def energy_check(f_input):
    # This should be stable across all size of SPC/e systems
    pe_per_mol_molecule_ref = -11.12
    pe_threshold = 2e-2
    if not args.quiet:
        print("SPC/E validates by checking the potential energy per mol-molecule at the beginning and end of the simulation.")
        print(f"This SPC/E system checks for {pe_per_mol_molecule_ref} kcal/mol-molecule with a threshold of {pe_threshold}.")
    file1 = open(f_input, 'r')
    sim_data = {}

    index_ct = 0
    n_molecules = 0
    for line in file1:
        if line.rstrip().endswith("angles"):
            n_molecules = int(line.split()[0])
            if not args.quiet:
                print(f"Found {n_molecules} molecules in the system.")
        elif line.find("Step") > -1:
            labels = line.split()
            line = next(file1)
            while not line.split()[0].strip() == 'Loop':
                sim_data[index_ct] = {}
                line = line.split()
                for j in range(0, len(line)):
                    sim_data[index_ct][labels[j]] = float(line[j])
                line = next(file1)
                index_ct += 1

    #pe_unit_0 = sim_data[0]['PotEng'] / (n_molecules * 6.022 * pow(10,23))
    #pe_unit_end = sim_data[index_ct-1]['PotEng'] / (n_molecules * 6.022 * pow(10,23))
    pe_unit_0 = sim_data[0]['PotEng'] / n_molecules
    pe_unit_end = sim_data[index_ct-1]['PotEng'] / n_molecules
    if abs(pe_unit_0 - pe_per_mol_molecule_ref) > pe_threshold:
        if not args.quiet:
            print(f"Failed energy validation, potential energy per mol-molecule at step 0 ({pe_unit_0}) does not match expected ({pe_per_mol_molecule_ref}).")
            return False
    elif abs(pe_unit_end - pe_per_mol_molecule_ref) > pe_threshold:
        if not args.quiet:
            print(f"Failed energy validation, potential energy per mol-molecule at end of simulation ({pe_unit_end}) does not match expected ({pe_per_mol_molecule_ref}).")
            return False
    elif not args.quiet:
        print(f"Energy validation passed, potential energy per mol-molecule at start & end ({pe_unit_0}, {pe_unit_end}) kcal/mol.")
    return True

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

# Check if args.input is a valid file
if not os.path.isfile(args.input):
    print("LAMMPS input file not found. Exiting.")
    exit(1)

check_result = check_file(f"{args.input}")
if not check_result:
    print("check_file failed, aborting check.")
    exit(1)
if not energy_check(f"{args.input}"):
    print("Energy check failed, aborting validation script.")
    exit(1)
else:
    perf_metric = get_performance(f"{args.input}")
    if perf_metric < 0:
        print("Retrieving LAMMPS performance failed. Aborting")
        exit(1)
    if perf_metric > 1e9:
        print(f"PASS, FOM = {perf_metric/pow(10,9)} gatom-steps/s")
    elif perf_metric > 1e6:
        print(f"PASS, FOM = {perf_metric/pow(10,6)} matom-steps/s")
    else:
        print(f"PASS, FOM = {perf_metric} atom-steps/s")
