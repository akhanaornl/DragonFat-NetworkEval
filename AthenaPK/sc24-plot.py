import matplotlib.pyplot as plt

# Data
nodes = [64, 512, 4096, 9261]
summit_default = [1.10e9, 1.02e9, 9.48e8, None]
summit_best = [1.10e9, 1.03e9, 9.46e8, None]
summit_random = [1.12e9, 1.03e9, 7.95e8, None]
frontier_default = [1.92e9, 1.90e9, 1.87e9, 1.86e9]  # Frontier-Default
frontier_best = [1.92e9, 1.90e9, 1.86e9, 1.86e9]  # Frontier-Best
frontier_random = [1.92e9, 1.92e9, 1.92e9, 1.82e9]  # Frontier-Random

# Plotting
plt.figure(figsize=(4.0, 3.2))

# Summit
plt.plot(nodes[:3], summit_default[:3], marker='o', label='Summit-Default', color='#fee0b6')
plt.plot(nodes[:3], summit_best[:3], marker='s', label='Summit-Block', color='#f1a340')
plt.plot(nodes[:3], summit_random[:3], marker='^', label='Summit-Random', color='#b35806')

# Frontier-Default
plt.plot(nodes, frontier_default, marker='D', label='Frontier-Default', color='#d8daeb')

# Frontier-Best
plt.plot(nodes, frontier_best, marker='P', label='Frontier-Block', color='#998ec3')
plt.plot(nodes, frontier_random, marker='X', label='Frontier-Random', color='#542788')

plt.xlabel('Nodes', fontsize=8)
plt.ylabel('Throughput (Zone-Cycles/Second/Node)', fontsize=8)
##plt.title('M-PsDNS')
plt.legend(fontsize=8, loc='lower center', ncol=2, frameon=True)
plt.grid(True)
plt.gca().set_ylim(bottom=0)

#plt.legend(fontsize=8, bbox_to_anchor=(0.5, 1.33), loc='upper center', ncol=2, frameon=False)


##fonts
#plt.legend(fontsize=8)
plt.xticks(fontsize=8.5)
plt.yticks(ticks=[0e9,2e9,1e9],fontsize=8.5)
plt.xscale('log')  # Set x-axis to log scale

plt.tight_layout()
plt.savefig('athenapk.pdf', format='pdf')

plt.show()

