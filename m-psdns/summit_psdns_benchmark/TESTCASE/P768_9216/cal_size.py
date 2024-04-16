def read_input_file(input_file):
    input_data = {}
    with open(input_file, 'r') as file:
        lines = file.readlines()
        input_data['nx'], input_data['ny'], input_data['nz'], input_data['nv'] = map(int, lines[1].strip().split(','))
        input_data['iproc'], input_data['jproc'] = map(int, lines[3].strip().split(','))
        input_data['nstep'] = int(lines[5].strip())
        input_data['tasks_per_node'] = int(lines[7].strip())
    return input_data

def calculate_data_sizes(input_data):
    total_size = input_data['nx'] * input_data['ny'] * input_data['nz'] * input_data['nv']
    rank_size = total_size // (input_data['iproc'] * input_data['jproc'])
    return rank_size

def main():
    input_file = "input"
    input_data = read_input_file(input_file)
    rank_size = calculate_data_sizes(input_data)
    print("Data size per rank:", rank_size)

if __name__ == "__main__":
    main()
