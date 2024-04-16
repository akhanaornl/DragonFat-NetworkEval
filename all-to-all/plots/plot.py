#!/usr/bin/env python3
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D

colors = ['#b35806','#f1a340','#fee0b6','#d8daeb','#998ec3','#542788']

def summitbw(infile,outfile):
    plt.figure(figsize=(4.0, 3.2))
    comms,commsize,count,msgsize,timemin,timeavg,timemax,bwmin,bwavg,bwmax = np.loadtxt(infile,unpack=True)
    msgsize *= 1024*1024*1024
    ilo = 0
    j = 0
    offsets = [0]

    for i in range(1,comms.size):
        if (comms[i] != comms[i-1]) or (i+1 == comms.size):
            offsets.append(i);

    def plotline(j,mark,c):
        ilo = offsets[j]
        ihi = offsets[j+1]
        label="{0:g} x {1:g} tasks".format(comms[ilo],commsize[ilo])
        plt.semilogx(msgsize[ilo:ihi],bwavg[ilo:ihi],label=label,marker=mark,color=c)
        #plt.loglog(msgsize[ilo:ihi],bwavg[ilo:ihi],label=label,marker=mark,color=c)

    plotline(11,'P',colors[2])
    plotline(7,'X',colors[3])
    plotline(4,'D',colors[1])
    plotline(2,'s',colors[4])
    plotline(1,'^',colors[0])
    plotline(0,'o',colors[5])
    plt.ylim(0,12)
    plt.xlabel('Total MPI_Alltoall Message Size per Rank (bytes)', fontsize=8)
    plt.ylabel('Total Bandwidth per Rank (GB/s)', fontsize=8)
    plt.legend(loc='upper left',fontsize=8,frameon=False)
    plt.xticks(fontsize=8.5)
    plt.yticks(fontsize=8.5)
    plt.grid = True
    plt.tight_layout()
    plt.savefig(outfile)
    plt.show()

def summittime(infile,outfile):
    plt.figure(figsize=(4.0, 3.2))
    comms,commsize,count,msgsize,timemin,timeavg,timemax,bwmin,bwavg,bwmax = np.loadtxt(infile,unpack=True)
    msgsize *= 1024*1024*1024
    ilo = 0
    j = 0
    offsets = [0]

    for i in range(1,comms.size):
        if (comms[i] != comms[i-1]) or (i+1 == comms.size):
            offsets.append(i);

    def plotline(j,mark,c):
        ilo = offsets[j]
        ihi = offsets[j+1]
        label="{0:g} x {1:g} tasks".format(comms[ilo],commsize[ilo])
        plt.loglog(msgsize[ilo:ihi],timeavg[ilo:ihi],label=label,marker=mark,color=c)

    plotline(0,'o',colors[5])
    plotline(1,'^',colors[0])
    plotline(2,'s',colors[4])
    plotline(4,'D',colors[1])
    plotline(7,'X',colors[3])
    plotline(11,'P',colors[2])
    plt.xlabel('Total MPI_Alltoall Message Size per Rank (bytes)', fontsize=8)
    plt.ylabel('Time (seconds)', fontsize=8)
    plt.legend(fontsize=8,frameon=False)
    plt.xticks(fontsize=8.5)
    plt.yticks(fontsize=8.5)
    plt.grid = True
    plt.tight_layout()
    plt.savefig(outfile)
    plt.show()

def frontierbw(infile,outfile):
    plt.figure(figsize=(4.0, 3.2))
    comms,commsize,count,msgsize,timemin,timeavg,timemax,bwmin,bwavg,bwmax = np.loadtxt(infile,unpack=True)
    msgsize *= 1024*1024*1024
    ilo = 0
    j = 0
    offsets = [0]

    for i in range(1,comms.size):
        if (comms[i] != comms[i-1]) or (i+1 == comms.size):
            offsets.append(i);

    def plotline(j,mark,c):
        ilo = offsets[j]
        ihi = offsets[j+1]
        label="{0:g} x {1:g} tasks".format(comms[ilo],commsize[ilo])
        plt.semilogx(msgsize[ilo:ihi],bwavg[ilo:ihi],label=label,marker=mark,color=c)
        #plt.loglog(msgsize[ilo:ihi],bwavg[ilo:ihi],label=label,marker=mark,color=c)

    plotline(12,'P',colors[2])
    plotline(7,'X',colors[3])
    plotline(4,'D',colors[1])
    plotline(2,'s',colors[4])
    plotline(1,'^',colors[0])
    plotline(0,'o',colors[5])
    plt.ylim(0,36)
    plt.xlabel('Total MPI_Alltoall Message Size per Rank (bytes)', fontsize=8)
    plt.ylabel('Total Bandwidth per Rank (GB/s)', fontsize=8)
    plt.legend(loc='upper left',fontsize=8,frameon=False)
    plt.xticks(fontsize=8.5)
    plt.yticks(fontsize=8.5)
    plt.grid = True
    plt.tight_layout()
    plt.savefig(outfile)
    plt.show()

def frontiertime(infile,outfile):
    plt.figure(figsize=(4.0, 3.2))
    comms,commsize,count,msgsize,timemin,timeavg,timemax,bwmin,bwavg,bwmax = np.loadtxt(infile,unpack=True)
    msgsize *= 1024*1024*1024
    ilo = 0
    j = 0
    offsets = [0]

    for i in range(1,comms.size):
        if (comms[i] != comms[i-1]) or (i+1 == comms.size):
            offsets.append(i);

    def plotline(j,mark,c):
        ilo = offsets[j]
        ihi = offsets[j+1]
        label="{0:g} x {1:g} tasks".format(comms[ilo],commsize[ilo])
        plt.loglog(msgsize[ilo:ihi],timeavg[ilo:ihi],label=label,marker=mark,color=c)

    plotline(0,'o',colors[5])
    plotline(1,'^',colors[0])
    plotline(2,'s',colors[4])
    plotline(4,'D',colors[1])
    plotline(7,'X',colors[3])
    plotline(12,'P',colors[2])
    plt.xlabel('Total MPI_Alltoall Message Size per Rank (bytes)', fontsize=8)
    plt.ylabel('Time (seconds)', fontsize=8)
    plt.legend(fontsize=8,frameon=False)
    plt.xticks(fontsize=8.5)
    plt.yticks(fontsize=8.5)
    plt.grid = True
    plt.tight_layout()
    plt.savefig(outfile)
    plt.show()

summitbw('Summit/2/always.3361373.contig.txt','summit.bw.contig.pdf')
summitbw('Summit/2/always.3361373.strided.txt','summit.bw.strided.pdf')
frontierbw('Frontier/2/slurm-1786061.contig.txt','frontier.bw.contig.pdf')
frontierbw('Frontier/2/slurm-1786061.strided.txt','frontier.bw.strided.pdf')

