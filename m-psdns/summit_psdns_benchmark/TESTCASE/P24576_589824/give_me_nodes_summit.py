#!/usr/bin/env python3

import argparse
import os
import sys
import random

parser = argparse.ArgumentParser(description="Script to distribute nodes among the nodes allocated to a job by switch group.")
parser.add_argument('-N', type=int, required=True, action='store', help="Number of nodes to generate binding for.")
parser.add_argument('--worst', action='store_true', help="Generate bindings for \"worst\" case -- random node placement across the network.")
parser.add_argument('--force-distribute', action='store_true', help="If set, always distribute nodes across as many switch groups as possible.")
# You can often feed the `$LSB_DJOB_HOSTFILE` environment variable directly into this flag
parser.add_argument('--node-file', type=str, default='./job.nodes', action='store', help="Path to a file containing the list of nodes (batch can be included).")
parser.add_argument('--erf-file', type=str, default='rank_reorder.erf', action='store', help="File name for ERF file.")
parser.add_argument('--ntasks-per-node', type=int, default=6, action='store', help="Number of ranks per node to generate binding for.")
parser.add_argument('--gpus-per-node', type=int, default=6, action='store', help="Number of GPUs available per node.")
parser.add_argument('--cpus-per-node', type=int, default=42, action='store', help="Number of CPU cores available per node.")

args = parser.parse_args()

if not os.path.isfile(args.node_file):
    print(f"Could not find node list file {args.node_file}.", file=sys.stderr)
    exit(1)

def read_node_file():
    """ Reads in the file containing the list of Summit nodes """
    ret = {}
    node_list = []
    node_index = 1
    with open(args.node_file, 'r') as in_f:
        for line in in_f:
            node_name = line.strip()
            if not ('batch' in node_name or 'login' in node_name):
                location = node_name[0:3]
                if not node_name in node_list:
                    node_list.append(node_name)
                    #ret[node_name] = location
                    # ERF files use the node index, not node name
                    ret[node_index] = location
                    node_index += 1
    return ret

def get_largest_ft_group(n2s):
    """ Parses the dictionary of node names to dragonfly groups to find the largest group """
    switch_counts = {}
    max_count = 0
    max_group = -1
    for node in n2s.keys():
        if not n2s[node] in switch_counts.keys():
            switch_counts[n2s[node]] = 1
        else:
            switch_counts[n2s[node]] += 1
        if switch_counts[n2s[node]] > max_count:
            max_count = switch_counts[n2s[node]]
            max_group = n2s[node]
    return [max_group, max_count]

def make_switch_to_node(n2s):
    """ Returns the inverse of the dictionary of node names to dragonfly groups """
    ret = {}
    for node in n2s.keys():
        if not n2s[node] in ret.keys():
            ret[n2s[node]] = [node]
        else:
            ret[n2s[node]].append(node)
    return ret

def print_erf(nodes):
    """ Prints the ERF file for use in jsrun """
    rank_number = 0
    hw_threads_per_core = 4
    threads_per_task = int(args.cpus_per_node / args.ntasks_per_node) * hw_threads_per_core
    print(f"Generating binding with {threads_per_task} hardware threads per task (4 hw threads per core)", file=sys.stderr)
    with open(f'{args.erf_file}', 'w+') as outf:
        outf.write('cpu_index_using: logical\n')
        outf.write('launch_distribution: packed\n')
        for i in range(0, len(nodes)):
            node_index = nodes[i]
            # Then write ntasks-per-node bindings
            # If the number of tasks are equal to the number of GPUs
            if (args.ntasks_per_node == args.gpus_per_node):
                for local_rank in range(0, args.ntasks_per_node):
                    start_cpu_index = local_rank*threads_per_task
                    outf.write(f'rank: {rank_number}: {{ host: {node_index}; cpu: {{ {start_cpu_index}-{start_cpu_index+threads_per_task-1} }}; gpu: {{ {local_rank} }} }}\n')
                    rank_number += 1
            else:
                print("Haven't yet implemented the ability to do multiple tasks per GPU! Exiting...", file=sys.stderr)
                exit(1)

nodes2switches = read_node_file()
big_switch_group, big_switch_group_ct = get_largest_ft_group(nodes2switches)
group2node = make_switch_to_node(nodes2switches)

print(f"Found biggest group = {big_switch_group}, count = {big_switch_group_ct}", file=sys.stderr)
print(f"Have {len(group2node.keys())} switches", file=sys.stderr)

assigned_nodes = []
added_nodes = 0

# Default to packing sequentially into as few groups as possible
if not (args.force_distribute or args.worst):
    # Then we just take the first args.N nodes in the job
    all_node_names = list(nodes2switches.keys())
    assigned_nodes = all_node_names[0:args.N]
    added_nodes = len(assigned_nodes)
elif args.force_distribute and not args.worst:
    # Else, distribute the nodes among the switch groups evenly, cyclically (then sort to achieve a block distribution)
    # Each iteration through the for-loop, this increments by 1 to grab the nth node from the node list
    # If a group runs out of nodes, skip it
    node_index = 0
    while added_nodes < args.N:
        for group in group2node.keys():
            if added_nodes < args.N and node_index < len(group2node[group]):
                print(f"Adding node {group2node[group][node_index]} from group {group}", file=sys.stderr)
                assigned_nodes.append(group2node[group][node_index])
                added_nodes += 1
        node_index += 1
    assigned_nodes.sort()
elif args.worst:
    # Else, generate a randomized list of node indexes and grab the first args.N node indexes from that list
    all_node_names = list(nodes2switches.keys())
    random.shuffle(all_node_names)
    assigned_nodes = all_node_names[0:args.N]
    added_nodes = len(assigned_nodes)

print_erf(assigned_nodes)

