#!/usr/bin/env python3

import argparse
import os
import sys

parser = argparse.ArgumentParser(description="Script to distribute nodes among the nodes allocated to a job by dragonfly group.")
parser.add_argument('--key', type=str, default='./dragonfly_topo.txt', action='store', help="Output from 'shasta_addr' describing the network topology in the current node pool.")
parser.add_argument('-N', type=int, required=True, action='store', help="Number of nodes to generate binding for.")
parser.add_argument('--randomize', action='store_true', help="Shuffle nodes by making a MPICH_RANK_REORDER file.")
parser.add_argument('--force-distribute', action='store_true', help="If set, always distribute nodes across as many groups as possible.")
parser.add_argument('--reorder-file', type=str, default='rank_reorder.txt', action='store', help="File name for MPICH_RANK_REORDER file.")
parser.add_argument('--ntasks-per-node', type=int, default=8, action='store', help="Number of nodes to generate binding for.")
parser.add_argument('-m', '--machine-name', type=str, default='frontier', action='store', help="Name to prefix nodes for.")

args = parser.parse_args()

if not os.path.isfile(args.key):
    print(f"Could not find key file {args.key}.", file=sys.stderr)
    exit(1)

def read_key_file():
    """ Reads in the dragonfly topology output by shasta_addr and returns a dictionary of node_name: dragonfly_group """
    ret = {}
    with open(args.key, 'r') as in_f:
        for line in in_f:
            node_name = line.split()[0]
            location = line.split()[8]
            dfly_group = int(location.split('.')[0])
            if not node_name in ret.keys():
                ret[node_name] = dfly_group
    return ret

def get_largest_dfly_group(dfly_groups):
    """ Parses the dictionary of node names to dragonfly groups to find the largest group """
    dfly_group_counts = {}
    max_count = 0
    max_group = -1
    for node in dfly_groups.keys():
        if not dfly_groups[node] in dfly_group_counts.keys():
            dfly_group_counts[dfly_groups[node]] = 1
        else:
            dfly_group_counts[dfly_groups[node]] += 1
        if dfly_group_counts[dfly_groups[node]] > max_count:
            max_count = dfly_group_counts[dfly_groups[node]]
            max_group = dfly_groups[node]
    return [max_group, max_count]

def make_dfly_group_to_node(dfly_groups):
    """ Returns the inverse of the dictionary of node names to dragonfly groups """
    ret = {}
    for node in dfly_groups.keys():
        if not dfly_groups[node] in ret.keys():
            ret[dfly_groups[node]] = [node]
        else:
            ret[dfly_groups[node]].append(node)
    return ret

def print_nodes(nodes):
    """ Prints the condensed node range for use in srun/sbatch lines """
    # Start by sorting the node numbers (still strings at this point)
    if len(nodes) == 1:
        print(f"{args.machine_name}[{nodes[0]}]")
        return
    nodes.sort()
    ret = []
    in_range = False
    just_dumped_range = False
    last_entry = -10
    start_range = -20
    for i in range(0, len(nodes)):
        cur_val = int(nodes[i])
        just_dumped_range = False
        if cur_val - int(last_entry) == 1 and in_range:
            # Then we're already in a range and we keep ignoring
            last_entry = nodes[i]
            continue
        elif cur_val - int(last_entry) == 1 and not in_range:
            # We're not in a range currently, but the last 2 numbers are in line
            in_range = True
            start_range = last_entry
            last_entry = nodes[i]
        elif (not cur_val - int(last_entry) == 1) and in_range:
            # Then the last_entry was the end of the range
            ret.append(f'{start_range}-{last_entry}')
            last_entry = nodes[i]
            in_range = False
            just_dumped_range = True
        elif (int(last_entry) > 0 and not cur_val - int(last_entry) == 1) and not in_range:
            # We're not in a range, and the last 2 numbers don't line up
            ret.append(last_entry)
            last_entry = nodes[i]
        elif last_entry < 0:
            last_entry = nodes[i]
        else:
            print(f"Uncaught: last_entry={last_entry}, cur_val={cur_val}")
    if in_range:
        ret.append(f'{start_range}-{last_entry}')
    elif just_dumped_range:
        ret.append(last_entry)
    print(f"{args.machine_name}[{','.join(ret)}]")

def make_rank_reorder_file():
    """ Creates a file with shuffled MPI rank numbers """
    # To achieve this, we will shuffle a list of the node numbers
    # Then add all ranks on each node to the list
    import random
    node_order = list(range(0, args.N))
    random.shuffle(node_order)
    rank_order = [ f'{n * args.ntasks_per_node}-{(n + 1) * args.ntasks_per_node - 1}' for n in node_order ]
    with open(args.reorder_file, 'w+') as reorder_file:
        reorder_file.write(','.join(rank_order))
        reorder_file.write('\n')

dfly_groups = read_key_file()
big_dfly_group, big_dfly_group_ct = get_largest_dfly_group(dfly_groups)
group2node = make_dfly_group_to_node(dfly_groups)

print(f"Found biggest group = {big_dfly_group}, count = {big_dfly_group_ct}", file=sys.stderr)
print(f"Have {len(group2node.keys())} dragonfly groups", file=sys.stderr)

assigned_nodes = []
added_nodes = 0

# If there are few enough nodes to fit in a single dragonfly group, do that. else, spread them across groups
# if it is close, print a warning to stderr to avoid shell output capture
if args.N <= big_dfly_group_ct and not args.force_distribute:
    # Then start assigning nodes in the same dragonfly group linearly
    for node in dfly_groups.keys():
        if added_nodes < args.N and dfly_groups[node] == big_dfly_group:
            assigned_nodes.append(node.replace(args.machine_name, ''))
            added_nodes += 1
else:
    # Else, distribute the nodes among the dragonfly groups evenly, cyclically
    # Each iteration through the for-loop, this increments by 1 to grab the nth node from the node list
    # If a group runs out of nodes, skip it
    node_index = 0
    while added_nodes < args.N:
        for group in group2node.keys():
            if added_nodes < args.N and node_index < len(group2node[group]):
                print(f"Adding node {group2node[group][node_index]} from group {group}", file=sys.stderr)
                assigned_nodes.append(group2node[group][node_index].replace(args.machine_name,''))
                added_nodes += 1
        node_index += 1

if args.randomize:
    print(f"Creating rank reorder file in {args.reorder_file}", file=sys.stderr)
    make_rank_reorder_file()

print_nodes(assigned_nodes)

