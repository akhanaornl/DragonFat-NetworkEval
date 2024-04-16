import matplotlib.pyplot as plt
import numpy as np

# Data
nodes = [64, 512, 4096, 9261]
palette= ['#b35806','#f1a340','#fee0b6','#d8daeb','#998ec3','#542788']
data = """
100.0000   90.1934   90.6056   None
100.0000   90.1012   90.7178   None
100.0000   90.1590   90.4247   None
100.0000   82.2980   91.3909   87.2606
100.0000   87.3568   96.8760   87.8466
100.0000   84.8383   89.8834   83.5747
"""

def parse_data():
    # Split the string into lines and then split each line into individual values
    lines = data.strip().split('\n')
    values = [line.split() for line in lines]

    # Convert the values to floats, replacing 'None' with numpy's NaN
    values = [[np.float32(val) if val != 'None' else np.nan for val in row] for row in values]

    # Create a 2D NumPy array from the values
    data_array = np.array(values)
    print(data_array)

    return (data_array)

    
def plot_eff(eff):

    # Plotting
    plt.figure(figsize=(4.5, 3.0))
    plt.xscale("log")

    # Summit
    plt.plot(nodes, eff[0,:], marker='o', linestyle='-', label='Summit-Default', color=palette[2])
    plt.plot(nodes, eff[1,:], marker='s', linestyle='-', label='Summit-Block',   color=palette[1])
    plt.plot(nodes, eff[2,:], marker='^', linestyle='-', label='Summit-Random',  color=palette[0])

    # Frontier
    plt.plot(nodes, eff[3,:], marker='D',  linestyle='-', label='Frontier-Default', color=palette[3])
    plt.plot(nodes, eff[4,:], marker='P',  linestyle='-', label='Frontier-Block',   color=palette[4])
    plt.plot(nodes, eff[5,:], marker='X',  linestyle='-', label='Frontier-Random',  color=palette[5])

    plt.xlabel('# Nodes', fontsize=8)
    plt.ylabel('Parallel Efficiency (%)', fontsize=8)
    plt.legend()
    plt.grid(True)

    plt.legend(fontsize=8, loc='lower center', ncol=2, frameon=True)


    ##fonts
    plt.xticks(fontsize=8.5)
    plt.yticks(fontsize=8.5)

    plt.tight_layout()
    plt.ylim(bottom=0, top=110)
    plt.savefig('flashx_p_eff.pdf', format='pdf')
    plt.close()

eff = parse_data()
plot_eff(eff)