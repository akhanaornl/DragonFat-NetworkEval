/*******************************************************************************
 * Copyright 2021 Hewlett Packard Enterprise Development LP
 *******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <regex.h>
#include "shasta_addr.h"

#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ioctl.h>
#include <net/if.h> 
#include <netinet/in.h>

#define PORT_MASK  63 
#define SW_MASK    31
#define GRP_MASK  511

#define SW_SHIFT    6
#define GRP_SHIFT  11

/********************************************************************************************
 * ASIC Port Numbering + Shasta River Network Architecture Implementation (09-ARS-1408))
 * int tor_edge_ports[] = { 8,9,12,13,26,27,30,31,42,43,46,47,56,57,60,61 };
 * int tor_edge_phys2log[] = { -1, -1, -1, -1, -1, -1, -1, -1, \
 *                              0,  1, -1, -1,  2,  3, -1, -1, \
 *                             -1, -1, -1, -1, -1, -1, -1, -1, \
 *                             -1, -1,  4,  5, -1, -1,  6,  7, \
 *                             -1, -1, -1, -1, -1, -1, -1, -1, \
 *                             -1, -1,  8,  9, -1, -1, 10, 11, \
 *                             -1, -1, -1, -1, -1, -1, -1, -1, \
 *                             12, 13, -1, -1, 14, 15, -1, -1 };
 ********************************************************************************************        
 *   ----------------------------------------------------------------------------------------
 *   Top Con| 01 | 03 | 05 | 07 | 09 | 11 | 13 | 15 | 17 | 19 | 21 | 23 | 25 | 27 | 29 | 31 | 
 *   ----------------------------------------------------------------------------------------
 *   Port   | 00 | 19 | 04 | 23 | 24 | 11 | 29 | 14 | 62 | 44 | 59 | 40 | 39 | 52 | 35 | 48 | 
 *          | 01 | 18 | 05 | 22 | 25 | 10 | 28 | 15 | 63 | 45 | 58 | 41 | 38 | 53 | 34 | 49 |
 *   ----------------------------------------------------------------------------------------
 *   Bot Con| 02 | 04 | 06 | 08 | 10 | 12 | 14 | 16 | 18 | 20 | 22 | 24 | 26 | 28 | 30 | 32 | 
 *   ----------------------------------------------------------------------------------------
 *   Port   | 16 | 03 | 20 | 07 | 08 | 27 | 13 | 30 | 46 | 61 | 43 | 56 | 55 | 36 | 51 | 32 |
 *          | 14 | 02 | 21 | 06 | 09 | 26 | 12 | 31 | 47 | 60 | 42 | 57 | 54 | 37 | 50 | 33 |
 *   ----------------------------------------------------------------------------------------
 ********************************************************************************************
 *  int tor_cl0_edge_ports[]  = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18,19,
 *                               20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,
 *                               40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,
 *                               60,61,62,63};
 * int tor_cl1_edge_ports[]   = { 2, 3, 6, 7, 8, 9,12,13,14,16,20,21,26,27,30,31,32,33,36,37,
 *                               42,43,46,47,50,51,54,55,56,57,60,61 };
 * int tor_cl2P_edge_ports[]  = { 8, 9,12,13,26,27,30,31,42,43,46,47,56,57,60,61 };
 * int mtn_edge_ports[]       = { 0, 1, 2, 3,16,17,18,19,32,33,34,35,48,49,50,51 };
 ********************************************************************************************/

int tor_cl0_edge_phys2log[]  = {  0,  1,  2,  3,  4,  5,  6,  7, \
                                  8,  9, 10, 11, 12, 13, 14, 15, \
                                 16, 17, 18, 19, 20, 21, 22, 23, \
                                 24, 25, 26, 27, 28, 29, 30, 31, \
                                 32, 33, 34, 35, 36, 37, 38, 39, \
                                 40, 41, 42, 43, 44, 45, 46, 47, \
                                 48, 49, 50, 51, 52, 53, 54, 55, \
                                 56, 57, 58, 59, 60, 61, 62, 63 };

int tor_cl1_edge_phys2log[]  = { -1, -1,  0,  1, -1, -1,  2,  3, \
                                  4,  5, -1, -1,  6,  7,  8, -1, \
                                  9, -1, -1, -1, 10, 11, -1, -1, \
                                 -1, -1, 12, 13, -1, -1, 14, 15, \
                                 16, 17, -1, -1, 18, 19, -1, -1, \
                                 -1, -1, 20, 21, -1, -1, 22, 23, \
                                 -1, -1, 24, 25, -1, -1, 26, 27, \
                                 28, 29, -1, -1, 30, 31, -1, -1 };

int tor_cl2P_edge_phys2log[] = { -1, -1, -1, -1, -1, -1, -1, -1, \
                                  0,  1, -1, -1,  2,  3, -1, -1, \
                                 -1, -1, -1, -1, -1, -1, -1, -1, \
                                 -1, -1,  4,  5, -1, -1,  6,  7, \
                                 -1, -1, -1, -1, -1, -1, -1, -1, \
                                 -1, -1,  8,  9, -1, -1, 10, 11, \
                                 -1, -1, -1, -1, -1, -1, -1, -1, \
                                 12, 13, -1, -1, 14, 15, -1, -1 };

int mtn_edge_phys2log[]      = {  0,  1,  2,  3, -1, -1, -1, -1, \
                                 -1, -1, -1, -1, -1, -1, -1, -1, \
                                  4,  5,  6,  7, -1, -1, -1, -1, \
                                 -1, -1, -1, -1, -1, -1, -1, -1, \
                                  8,  9, 10, 11, -1, -1, -1, -1, \
                                 -1, -1, -1, -1, -1, -1, -1, -1, \
                                 12, 13, 14, 15, -1, -1, -1, -1, \
                                 -1, -1, -1, -1, -1, -1, -1, -1 };

void *strip_newline(char *buf) {
  buf[strcspn(buf, "\n")] = 0;
  return(buf);
}

char *logaddr2string(int log_addr, char *name, size_t namelen)
{
     int group_id = (log_addr >> 9) & 511;
     int switch_id = (log_addr >> 4 ) & 31;
     int port_id = log_addr & 15;
     snprintf(name, namelen, "%0.3d.%0.2d.%0.2d", group_id, switch_id, port_id);
     return(name);
}

int macaddr2logaddr(char *macaddr, sysclass type, int debug)
{
    int a, b, c, d, e, f;
    if (sscanf(macaddr,"%2x:%2x:%2x:%2x:%2x:%2x",&a,&b,&c,&d,&e,&f) == 6) {
        int addr = d * 65536 + e * 256 + f;
        int port_id = addr & PORT_MASK;
        int switch_id = (addr >> SW_SHIFT) & SW_MASK;
        int group_id = (addr >> GRP_SHIFT) & GRP_MASK;
        int log_port_id;

        // Check if we're using a mountain or river system. 
        // Additional check needed for river, only 1 config
        // for mountain
        
        switch(type) {
          case class0:
            if ((log_port_id = tor_cl0_edge_phys2log[port_id]) < 0) {
              if (debug)
                printf("Failed class 0 with port_id: %d, switch_id: %d, group_id: %d\n", port_id, switch_id, group_id);
              return(-1);
	    }
            break;
          case class1:
            if ((log_port_id = tor_cl1_edge_phys2log[port_id]) < 0) {
              if (debug)
                printf("Failed class 1 with port_id: %d, switch_id: %d, group_id: %d\n", port_id, switch_id, group_id);
              return(-1);
            }
            break;
          case class2:
          case class3:
          case class4:
            if ((log_port_id = mtn_edge_phys2log[port_id]) < 0) {
              if (debug)
                printf("Failed to match with Mountain, checking River...\n");

              if ((log_port_id = tor_cl2P_edge_phys2log[port_id]) < 0) {
                if (debug)
                  printf("Failed class 2+ with port_id: %d, switch_id: %d, group_id: %d\n", port_id, switch_id, group_id);
                return(-1);
              }
            }
            break;
          default:
            fprintf(stderr, "Could not compile regex\n");
            return(-1);
        }
	return(group_id * 512 + switch_id * 16 + log_port_id);
    }
    return(-1);
} 

int getmacaddr_files(char *macaddr, size_t addrlen, int nicNum)
{
  FILE *fp;
  char line[128], *fname, **pp;
  char ifcfgFile[50];
  
  sprintf(ifcfgFile, "/etc/sysconfig/network/ifcfg-hsn%d", nicNum);
  
  // the network configuration filenames vary between machines
  char *places[] = { "/etc/sysconfig/network/ifcfg-hsn",		\
  		   ifcfgFile,						\
  		   "/etc/sysconfig/network-scripts/ifcfg-enp94s0",	\
  		   "/etc/sysconfig/network-scripts/ifcfg-enp92s0",	\
  		   0 };

  for (pp=places; (fname = *pp); pp++) {
    if ((fp = fopen(fname,"r"))) {
      while (fgets(line, sizeof(line), fp)) {
        char *key = strtok(line, "=");
        char *val = strtok(NULL, "=");
        char *tmp = strtok(val, "'\"");
	
        if (tmp != NULL) {
          val = tmp;
        }
	
        if ((strcmp(key, "LLADDR") == 0 || strcmp(key, "MACADDR") == 0) && val) {
          int len = strlen(val);
          if (len > 0 && val[len-1] == '\n') val[len-1] = 0;
          strncpy(macaddr, val, addrlen);
          fclose(fp);
          return(0);
        }
      }
      fclose(fp);
    }
  }
  strncpy(macaddr, "Unknown", addrlen);
  return(-1);
}
  
//fall-back mac address function - try to read etc/hosts file for MAC ADDR
int getmacaddr_hosts(char *macaddr, size_t addrlen, char *hostname, size_t hostlen, int nicNum)
{
  char line[128];
  char* fname      = "/etc/hosts";
  regex_t regex;
  int re;
  FILE *fp;
  char hostNic[50];
  
  sprintf(hostNic, "%sh%d", hostname, nicNum);

  re = regcomp(&regex, MACREGEX, REG_EXTENDED); //MAC ADDR regex
  if (re) {
    fprintf(stderr, "Could not compile regex\n");
    return(-1);
  }
  
  if ((fp = fopen(fname,"r"))) {
    while (fgets(line, sizeof(line), fp)) {
      //check for hostname in line
      if (strstr(line, hostname) != NULL) {	  
        char *tmp = strtok(line, WHITESPACE);

        while(tmp != NULL) {
          re = regexec(&regex, tmp, 0, NULL, 0);
		  
          if (!re) {
            strncpy(macaddr, tmp, addrlen);
            fclose(fp);
            return(0);
          }
          else if (re != REG_NOMATCH) {
            char msgbuf[100];
	      
            regerror(re, &regex, msgbuf, sizeof(msgbuf));
            fprintf(stderr, "Regex match failed: %s\n", msgbuf);
            fclose(fp);
            return(-1);
          }
          tmp = strtok(NULL, WHITESPACE);
        }
      }
    }
    fclose(fp);
  }
 
  strncpy(macaddr, "Unknown", addrlen);
  return(-1);
}

int getmacaddr_ioctl(char *macaddr, size_t addrlen, int nicNum)
{
 int i, soc;
 unsigned char mac_bytes[6];
 struct ifreq if_req;

#if defined(OAT)
  sprintf(if_req.ifr_name,"eth%d",nicNum);
#else
  sprintf(if_req.ifr_name,"hsn%d",nicNum);
#endif

  soc = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
  if (soc != -1) {
    if (ioctl(soc, SIOCGIFHWADDR, &if_req) == 0) {
      memcpy(mac_bytes, if_req.ifr_hwaddr.sa_data, 6);
      for(i=0; i < 6; ++i)
        sprintf(macaddr, "%s%s%02x", ((i==0) ? "" : macaddr), ((i==0) ? "" : ":"), mac_bytes[i]);
    } else {
      return(-1);
    }
  }
  return (0);
}

int getmacaddr(char *macaddr, size_t addrlen, char *hostname, size_t hostlen, int localId, int nic, int verbose, int debug)
{
  char file[128], line[128];
  FILE *fp;

  if (getmacaddr_ioctl(macaddr, addrlen, nic) < 0) {
    if ((verbose || debug) && localId == 0)
        printf("Failed to get algorithmic MAC address from ioctl, trying file list\n");

    if (getmacaddr_files(macaddr, addrlen, nic) < 0) {
      if ((verbose || debug) && localId == 0)
        printf("Failed to get algorithmic MAC address from known network files, checking /etc/hosts\n");

      if (getmacaddr_hosts(macaddr, addrlen, hostname, hostlen, nic) < 0) {
        if (localId == 0)
          fprintf(stderr, "Failed to get algorithmic MAC addr for Shasta node %s\n", hostname);

        // Next place to try /sys/class/net/hsn0/address
        sprintf(file, "/sys/class/net/hsn%d/address", nic);
        if ((fp = fopen(file,"r"))) {
          while (fgets(line, sizeof(line), fp)) {
            strncpy(macaddr, line, addrlen);
            strip_newline(macaddr);
          }

     	  fclose(fp);
	  return(0);
        }
        strncpy(macaddr, "Unknown", addrlen);
        return -1;
      } 
    }
  }
  
  return 0;
}

#ifdef BUILD_TEST

// Usage: shasta_addr [num_nics [class]]

int main(int argc, char **argv)
{
    char hostname[32], macaddr[32], name[32];
    int logaddr;
    int i, numNics=1;
    sysclass type=class2;

    if (argc > 1)
      numNics = atoi(argv[1]);

    if (argc > 2)
      type = (sysclass)atoi(argv[2]);

    gethostname(hostname, sizeof(hostname));

    for ( i=0; i < numNics; ++i) {

      if (getmacaddr_ioctl(macaddr, sizeof(macaddr), i) < 0) {
	fprintf(stderr, "%s: NIC %d failed to get algorithmic MAC address from ioctl, trying file list\n", hostname, i);
	getmacaddr_files(macaddr, sizeof(macaddr), i);
      }

      if ((logaddr = macaddr2logaddr(macaddr, type, 0)) < 0) {
	fprintf(stderr,"%s: NIC %d failed to parse MAC addr: %s\n", hostname, i, macaddr);
	exit(1);
      }
      printf("%s NIC %d macaddr %s logaddr %0.5d location %s\n", hostname, i, macaddr, logaddr, logaddr2string(logaddr, name, sizeof(name)));
    }
    exit(0);
}

#endif

