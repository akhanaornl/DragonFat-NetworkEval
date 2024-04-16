import matplotlib.pyplot as plt
from matplotlib.ticker import StrMethodFormatter
from mpl_toolkits.axes_grid1 import host_subplot
import numpy as np

# Data
nodes = [64, 125, 216, 343, 512, 1728, 4096, 9261]
nodes_ticks = [64, 512, 4096, 9261]
palette= ['#b35806','#f1a340','#fee0b6','#d8daeb','#998ec3','#542788']
data = """
4.91	4.24	4.34	3.38	3.27	2.85	2.69    None
5.00	4.37	4.33	3.66	3.52	2.25	1.73    None
20.21	17.39	16.24	16.82	16.15	15.31	15.49   14.23
20.13	16.66	15.98	15.35	15.32	13.90	12.59   6.63
100.00	86.29	88.36	68.94	66.58	58.07	54.88   None
100.00	87.52	86.61	73.14	70.37	45.04	34.67   None
100.00	86.04	80.36	83.22	79.91	75.75	76.63   70.39
100.00	82.77	79.39	76.25	76.11	69.05	62.56   32.94
1.56	6.25	25.00	100.00	400.00  None    None    None
16.49	18.11	17.86	17.57	17.90   None    None    None
0.15	0.17	0.82	0.46	0.38    None    None    None
4.68	4.66	5.00	4.93	4.83    None    None    None
0.01	0.09	0.09	0.07	0.04    None    None    None
"""

def parse_data():
    # Split the string into lines and then split each line into individual values
    lines = data.strip().split('\n')
    values = [line.split() for line in lines]

    # Convert the values to floats, replacing 'None' with numpy's NaN
    values = [[np.float32(val) if val != 'None' else np.nan for val in row] for row in values]

    # Create a 2D NumPy array from the values
    data_array = np.array(values)

    return (data_array[0:4,:], data_array[4:8,:], data_array[8:13])

def plot_bw(bw):

    # Plotting
    plt.figure(figsize=(5.0, 3.5))
    plt.xscale("log")
    

    # Summit
    plt.plot(nodes, bw[0,:], marker='s', linestyle='-', label='Summit-Block', color=palette[1])
    plt.plot(nodes, bw[1,:], marker='^', linestyle='-', label='Summit-Random', color=palette[0])

    # Frontier 
    plt.plot(nodes, bw[2,:], marker='P',  linestyle='-', label='Frontier-Block', color=palette[-2])
    plt.plot(nodes, bw[3,:], marker='X', linestyle='-', label='Frontier-Random', color=palette[-1])

    plt.xlabel('# Nodes', fontsize=8)
    plt.ylabel('Per Rank Bandwidth (GB/s)', fontsize=8)
    plt.legend()
    plt.grid(True)

    plt.legend(fontsize=8, loc='upper center', ncol=2, frameon=True)

    ##fonts
    plt.xticks(nodes, labels=nodes,fontsize=8.5)
    plt.yticks(range(0, 26, 5), fontsize=8.5)

    plt.tight_layout()
    plt.ylim(bottom=0, top=22)
    plt.savefig('ember.eps', format='eps')
    plt.show()
    plt.close()
    

def plot_eff(eff):

    # Plotting
    plt.figure(figsize=(5.0, 3.5))
    plt.xscale("log")

    # Summit
    plt.plot(nodes, eff[0,:], marker='s', linestyle='-', label='Summit-Block', color=palette[1])
    plt.plot(nodes, eff[1,:], marker='^', linestyle='-', label='Summit-Random', color=palette[0])

    # Frontier
    plt.plot(nodes, eff[2,:], marker='P',  linestyle='-', label='Frontier-Block', color=palette[-2])
    plt.plot(nodes, eff[3,:], marker='X', linestyle='-', label='Frontier-Random', color=palette[-1])

    plt.xlabel('# Nodes', fontsize=8)
    plt.ylabel('Parallel Efficiency (%)', fontsize=8)
    plt.legend()
    plt.grid(True)

    plt.legend(fontsize=8, loc='upper center', ncol=2, frameon=True)


    ##fonts
    plt.xticks(nodes, labels=nodes, fontsize=8.5)
    plt.yticks(fontsize=8.5)

    plt.tight_layout()
    plt.ylim(bottom=0, top=110)
    plt.savefig('ember_p_eff.eps', format='eps')
    plt.show()
    plt.close()

def plot_buff(buff):
    # Plotting
    plt.rcParams["figure.figsize"] = (5.0, 3.5)
    fig = plt.figure()
    ax1 = fig.add_subplot(111)
    ax2 = ax1.twiny()

    ax1.semilogx()
    ax2.semilogx()

    # Summit
    ax1.plot(buff[0,:], buff[3,:], marker='s', linestyle='-', label='Summit', color=palette[1])    
    ax1.errorbar(buff[0,:], buff[3,:], yerr=buff[4,:], fmt='.',color=palette[0])

    # Frontier
    ax1.plot(buff[0,:], buff[1,:], marker='P',linestyle='-', label='Frontier', color=palette[-2])
    ax1.errorbar(buff[0,:], buff[1,:], yerr=buff[2,:], fmt='.', color=palette[-1])

    # ticks
    ax1.set_xticks(buff[0,0:5])
    ax1.set_xticklabels(buff[0,0:5])
    ax2.set_xticks(buff[0,0:5])
    ax2.set_xticklabels([64, 128, 256, 512, 1024])

    ax1.xaxis.set_major_formatter(StrMethodFormatter('{x:,.2f}'))

    ax1.set_xlabel('Max Buffer Size (MB)', fontsize=8)
    ax1.set_ylabel('Per Rank Bandwidth (GB/s)', fontsize=8)
    ax2.set_xlabel("Axis Grid Size per MPI rank", fontsize=8)

    ax1.legend()
    ax1.grid(True)
    ax1.legend(fontsize=8, loc='upper center', ncol=2, frameon=True)


    ##fonts
    ax1.tick_params(axis='both', labelsize=8.5)
    ax2.tick_params(axis='both', labelsize=8.5)

    ax1.set_xlim(left=1)
    ax1.set_ylim(bottom=0, top=22)
    ax2.set_xlim(ax1.get_xlim())

    plt.savefig('ember_buffer.eps', format='eps')
    plt.show()
    plt.close()

bw, eff, buff = parse_data()
plot_bw(bw)
plot_eff(eff)
plot_buff(buff)
