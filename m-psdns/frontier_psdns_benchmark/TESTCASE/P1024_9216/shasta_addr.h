/*******************************************************************************
 * Copyright 2020 Hewlett Packard Enterprise Development LP
 *******************************************************************************/
// shasta_addr.h
// // extract stasta algorithmic mac and convert to a logical address

#ifndef __SHASTA_ADDR_H__
#define __SHASTA_ADDR_H__

#define WHITESPACE " \t\n"
#define MACREGEX   "^([a-fA-F0-9]{2}[:]){5}([a-fA-F0-9]{2})$"

typedef enum System_Class {class0,class1,class2,class3,class4} sysclass;

extern char *logaddr2string(int log_addr, char *name, size_t namelen);
extern int getmacaddr(char *macaddr, size_t addrlen, char *hostname, size_t hostlen, int localId, int nic, int verbose, int debug);
extern int macaddr2logaddr(char *macaddr, sysclass type, int debug);
#endif

