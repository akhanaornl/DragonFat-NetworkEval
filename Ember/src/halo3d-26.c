// Copyright 2009-2018 Sandia Corporation. Under the terms
// of Contract DE-NA0003525 with Sandia Corporation, the U.S.
// Government retains certain rights in this software.
//
// Copyright (c) 2009-2018, Sandia Corporation
// All rights reserved.
//
// Portions are copyright of other developers:
// See the file CONTRIBUTORS.TXT in the top level directory
// the distribution for more information.
//
// This file is part of the SST software package. For license
// information, see the LICENSE file in the top level directory of the
// distribution.

#include <errno.h>
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#ifdef WITH_HIP
#include <hip/hip_runtime.h>
#define accMalloc hipMalloc 
#define accMemcpy hipMemcpy
#define accMemcpyHostToDevice hipMemcpyHostToDevice
#define accFree hipFree
#elif WITH_CUDA
#include <cuda_runtime.h>
#define accMalloc cudaMalloc 
#define accMemcpy cudaMemcpy
#define accMemcpyHostToDevice cudaMemcpyHostToDevice
#define accFree cudaFree
#endif

void get_position(const int rank, const int pex, const int pey, const int pez,
                  int* myX, int* myY, int* myZ) {
  const int plane = rank % (pex * pey);
  *myY = plane / pex;
  *myX = (plane % pex) != 0 ? (plane % pex) : 0;
  *myZ = rank / (pex * pey);
}

int convert_position_to_rank(const int pX, const int pY, const int pZ,
                             const int myX, const int myY, const int myZ) {
  // Check if we are out of bounds on the grid
  if ((myX < 0) || (myY < 0) || (myZ < 0) || (myX >= pX) || (myY >= pY) ||
      (myZ >= pZ)) {
    return -1;
  } else {
    return (myZ * (pX * pY)) + (myY * pX) + myX;
  }
}

int main(int argc, char* argv[]) {
  MPI_Init(&argc, &argv);

  int me = -1;
  int world = -1;

  MPI_Comm_rank(MPI_COMM_WORLD, &me);
  MPI_Comm_size(MPI_COMM_WORLD, &world);

  int pex = world;
  int pey = 1;
  int pez = 1;

  int nx = 10;
  int ny = 10;
  int nz = 10;

  int repeats = 100;
  int vars = 1;

  long sleep = 1000;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-nx") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -nx without a value.\n");
        }

        exit(-1);
      }

      nx = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-ny") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -ny without a value.\n");
        }

        exit(-1);
      }

      ny = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-nz") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -nz without a value.\n");
        }

        exit(-1);
      }

      nz = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-pex") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -pex without a value.\n");
        }

        exit(-1);
      }

      pex = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-pey") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -pey without a value.\n");
        }

        exit(-1);
      }

      pey = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-pez") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -pez without a value.\n");
        }

        exit(-1);
      }

      pez = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-iterations") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -iterations without a value.\n");
        }

        exit(-1);
      }

      repeats = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-vars") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -vars without a value.\n");
        }

        exit(-1);
      }

      vars = atoi(argv[i + 1]);
      ++i;
    } else if (strcmp(argv[i], "-sleep") == 0) {
      if (i == argc) {
        if (me == 0) {
          fprintf(stderr, "Error: specified -sleep without a value.\n");
        }

        exit(-1);
      }

      sleep = atol(argv[i + 1]);
      ++i;
    } else {
      if (0 == me) {
        fprintf(stderr, "Unknown option: %s\n", argv[i]);
      }

      exit(-1);
    }
  }

  MPI_Barrier(MPI_COMM_WORLD);

  if ((pex * pey * pez) != world) {
    if (0 == me) {
      fprintf(stderr, "Error: rank grid does not equal number of ranks.\n");
      fprintf(stderr, "%7d x %7d x %7d != %7d\n", pex, pey, pez, world);
    }

    exit(-1);
  }

  MPI_Barrier(MPI_COMM_WORLD);

  if (me == 0) {
    printf("# MPI Nearest Neighbor Communication\n");
    printf("# Info:\n");
    printf("# Processor Grid:         %7d x %7d x %7d\n", pex, pey, pez);
    printf("# Data Grid (per rank):   %7d x %7d x %7d\n", nx, ny, nz);
    printf("# Iterations:             %7d\n", repeats);
    printf("# Variables:              %7d\n", vars);
    printf("# Sleep:                  %7ld\n", sleep);
  }

  int posX, posY, posZ;
  get_position(me, pex, pey, pez, &posX, &posY, &posZ);

  const int xFaceUp =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY, posZ);
  const int xFaceDown =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY, posZ);
  const int yFaceUp =
      convert_position_to_rank(pex, pey, pez, posX, posY + 1, posZ);
  const int yFaceDown =
      convert_position_to_rank(pex, pey, pez, posX, posY - 1, posZ);
  const int zFaceUp =
      convert_position_to_rank(pex, pey, pez, posX, posY, posZ + 1);
  const int zFaceDown =
      convert_position_to_rank(pex, pey, pez, posX, posY, posZ - 1);

  const int vertexA =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY - 1, posZ - 1);
  const int vertexB =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY - 1, posZ + 1);
  const int vertexC =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY + 1, posZ - 1);
  const int vertexD =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY + 1, posZ + 1);
  const int vertexE =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY - 1, posZ - 1);
  const int vertexF =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY - 1, posZ + 1);
  const int vertexG =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY + 1, posZ - 1);
  const int vertexH =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY + 1, posZ + 1);

  const int edgeA =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY - 1, posZ);
  const int edgeB =
      convert_position_to_rank(pex, pey, pez, posX, posY - 1, posZ - 1);
  const int edgeC =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY - 1, posZ);
  const int edgeD =
      convert_position_to_rank(pex, pey, pez, posX, posY - 1, posZ + 1);
  const int edgeE =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY, posZ + 1);
  const int edgeF =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY, posZ + 1);
  const int edgeG =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY, posZ - 1);
  const int edgeH =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY, posZ - 1);
  const int edgeI =
      convert_position_to_rank(pex, pey, pez, posX - 1, posY + 1, posZ);
  const int edgeJ =
      convert_position_to_rank(pex, pey, pez, posX, posY + 1, posZ + 1);
  const int edgeK =
      convert_position_to_rank(pex, pey, pez, posX + 1, posY + 1, posZ);
  const int edgeL =
      convert_position_to_rank(pex, pey, pez, posX, posY + 1, posZ - 1);

  double send_vertexA = 1.0;
  double send_vertexB = 1.0;
  double send_vertexC = 1.0;
  double send_vertexD = 1.0;
  double send_vertexE = 1.0;
  double send_vertexF = 1.0;
  double send_vertexG = 1.0;
  double send_vertexH = 1.0;

  double recv_vertexA = 1.0;
  double recv_vertexB = 1.0;
  double recv_vertexC = 1.0;
  double recv_vertexD = 1.0;
  double recv_vertexE = 1.0;
  double recv_vertexF = 1.0;
  double recv_vertexG = 1.0;
  double recv_vertexH = 1.0;

  int requestcount = 0;
  MPI_Status* status;
  status = (MPI_Status*)malloc(sizeof(MPI_Status) * 52);

  MPI_Request* requests;
  requests = (MPI_Request*)malloc(sizeof(MPI_Request) * 52);

  double* edgeASendBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeBSendBuffer = (double*)malloc(sizeof(double) * nx * vars);
  double* edgeCSendBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeDSendBuffer = (double*)malloc(sizeof(double) * nx * vars);
  double* edgeESendBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeFSendBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeGSendBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeHSendBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeISendBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeJSendBuffer = (double*)malloc(sizeof(double) * nx * vars);
  double* edgeKSendBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeLSendBuffer = (double*)malloc(sizeof(double) * nx * vars);

  double* edgeARecvBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeBRecvBuffer = (double*)malloc(sizeof(double) * nx * vars);
  double* edgeCRecvBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeDRecvBuffer = (double*)malloc(sizeof(double) * nx * vars);
  double* edgeERecvBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeFRecvBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeGRecvBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeHRecvBuffer = (double*)malloc(sizeof(double) * ny * vars);
  double* edgeIRecvBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeJRecvBuffer = (double*)malloc(sizeof(double) * nx * vars);
  double* edgeKRecvBuffer = (double*)malloc(sizeof(double) * nz * vars);
  double* edgeLRecvBuffer = (double*)malloc(sizeof(double) * nx * vars);

  for (int i = 0; i < nz; ++i) {
    edgeASendBuffer[i] = (double)i;
    edgeARecvBuffer[i] = 0.0;
    edgeCSendBuffer[i] = (double)i;
    edgeCRecvBuffer[i] = 0.0;
    edgeISendBuffer[i] = (double)i;
    edgeIRecvBuffer[i] = 0.0;
    edgeKSendBuffer[i] = (double)i;
    edgeKRecvBuffer[i] = 0.0;
  }

  for (int i = 0; i < ny; ++i) {
    edgeESendBuffer[i] = (double)i;
    edgeERecvBuffer[i] = 0.0;
    edgeFSendBuffer[i] = (double)i;
    edgeFRecvBuffer[i] = 0.0;
    edgeGSendBuffer[i] = (double)i;
    edgeGRecvBuffer[i] = 0.0;
    edgeHSendBuffer[i] = (double)i;
    edgeHRecvBuffer[i] = 0.0;
  }

  for (int i = 0; i < nx; ++i) {
    edgeBSendBuffer[i] = (double)i;
    edgeBRecvBuffer[i] = 0.0;
    edgeDSendBuffer[i] = (double)i;
    edgeDRecvBuffer[i] = 0.0;
    edgeJSendBuffer[i] = (double)i;
    edgeJRecvBuffer[i] = 0.0;
    edgeLSendBuffer[i] = (double)i;
    edgeLRecvBuffer[i] = 0.0;
  }

  double* xFaceUpSendBuffer = (double*)malloc(sizeof(double) * ny * nz * vars);
  double* xFaceUpRecvBuffer = (double*)malloc(sizeof(double) * ny * nz * vars);

  double* xFaceDownSendBuffer = (double*)malloc(sizeof(double) * ny * nz * vars);
  double* xFaceDownRecvBuffer = (double*)malloc(sizeof(double) * ny * nz * vars);

  for (int i = 0; i < ny * nz * vars; i++) {
    xFaceUpSendBuffer[i] = i;
    xFaceUpRecvBuffer[i] = i;
    xFaceDownSendBuffer[i] = i;
    xFaceDownRecvBuffer[i] = i;
  }

  double* yFaceUpSendBuffer = (double*)malloc(sizeof(double) * nx * nz * vars);
  double* yFaceUpRecvBuffer = (double*)malloc(sizeof(double) * nx * nz * vars);

  double* yFaceDownSendBuffer = (double*)malloc(sizeof(double) * nx * nz * vars);
  double* yFaceDownRecvBuffer = (double*)malloc(sizeof(double) * nx * nz * vars);

  for (int i = 0; i < nx * nz * vars; i++) {
    yFaceUpSendBuffer[i] = i;
    yFaceUpRecvBuffer[i] = i;
    yFaceDownSendBuffer[i] = i;
    yFaceDownRecvBuffer[i] = i;
  }

  double* zFaceUpSendBuffer = (double*)malloc(sizeof(double) * nx * ny * vars);
  double* zFaceUpRecvBuffer = (double*)malloc(sizeof(double) * nx * ny * vars);

  double* zFaceDownSendBuffer = (double*)malloc(sizeof(double) * nx * ny * vars);
  double* zFaceDownRecvBuffer = (double*)malloc(sizeof(double) * nx * ny * vars);

  for (int i = 0; i < nx * ny * vars; i++) {
    zFaceUpSendBuffer[i] = i;
    zFaceUpRecvBuffer[i] = i;
    zFaceDownSendBuffer[i] = i;
    zFaceDownRecvBuffer[i] = i;
  }

#if defined (WITH_HIP) || defined (WITH_CUDA)
double* edgeASendBuffer_h;
double* edgeBSendBuffer_h;
double* edgeCSendBuffer_h;
double* edgeDSendBuffer_h;
double* edgeESendBuffer_h;
double* edgeFSendBuffer_h;
double* edgeGSendBuffer_h;
double* edgeHSendBuffer_h;
double* edgeISendBuffer_h;
double* edgeJSendBuffer_h;
double* edgeKSendBuffer_h;
double* edgeLSendBuffer_h;
double* edgeARecvBuffer_h;
double* edgeBRecvBuffer_h;
double* edgeCRecvBuffer_h;
double* edgeDRecvBuffer_h;
double* edgeERecvBuffer_h;
double* edgeFRecvBuffer_h;
double* edgeGRecvBuffer_h;
double* edgeHRecvBuffer_h;
double* edgeIRecvBuffer_h;
double* edgeJRecvBuffer_h;
double* edgeKRecvBuffer_h;
double* edgeLRecvBuffer_h;
double* xFaceUpSendBuffer_h;
double* xFaceUpRecvBuffer_h;
double* xFaceDownSendBuffer_h;
double* xFaceDownRecvBuffer_h;
double* yFaceUpSendBuffer_h;
double* yFaceUpRecvBuffer_h;
double* yFaceDownSendBuffer_h;
double* yFaceDownRecvBuffer_h;
double* zFaceUpSendBuffer_h;
double* zFaceUpRecvBuffer_h;
double* zFaceDownSendBuffer_h;
double* zFaceDownRecvBuffer_h;

accMalloc(&edgeASendBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeBSendBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeCSendBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeDSendBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeESendBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeFSendBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeGSendBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeHSendBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeISendBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeJSendBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeKSendBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeLSendBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeARecvBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeBRecvBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeCRecvBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeDRecvBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeERecvBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeFRecvBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeGRecvBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeHRecvBuffer_h, sizeof(double) * ny * vars);
accMalloc(&edgeIRecvBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeJRecvBuffer_h, sizeof(double) * nx * vars);
accMalloc(&edgeKRecvBuffer_h, sizeof(double) * nz * vars);
accMalloc(&edgeLRecvBuffer_h, sizeof(double) * nx * vars);
accMalloc(&xFaceUpSendBuffer_h, sizeof(double) * ny * nz * vars);
accMalloc(&xFaceUpRecvBuffer_h, sizeof(double) * ny * nz * vars);
accMalloc(&xFaceDownSendBuffer_h, sizeof(double) * ny * nz * vars);
accMalloc(&xFaceDownRecvBuffer_h, sizeof(double) * ny * nz * vars);
accMalloc(&yFaceUpSendBuffer_h, sizeof(double) * nx * nz * vars);
accMalloc(&yFaceUpRecvBuffer_h, sizeof(double) * nx * nz * vars);
accMalloc(&yFaceDownSendBuffer_h, sizeof(double) * nx * nz * vars);
accMalloc(&yFaceDownRecvBuffer_h, sizeof(double) * nx * nz * vars);
accMalloc(&zFaceUpSendBuffer_h, sizeof(double) * nx * ny * vars);
accMalloc(&zFaceUpRecvBuffer_h, sizeof(double) * nx * ny * vars);
accMalloc(&zFaceDownSendBuffer_h, sizeof(double) * nx * ny * vars);
accMalloc(&zFaceDownRecvBuffer_h, sizeof(double) * nx * ny * vars);

accMemcpy(edgeASendBuffer_h, edgeASendBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeBSendBuffer_h, edgeBSendBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeCSendBuffer_h, edgeCSendBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeDSendBuffer_h, edgeDSendBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeESendBuffer_h, edgeESendBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeFSendBuffer_h, edgeFSendBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeGSendBuffer_h, edgeGSendBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeHSendBuffer_h, edgeHSendBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeISendBuffer_h, edgeISendBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeJSendBuffer_h, edgeJSendBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeKSendBuffer_h, edgeKSendBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeLSendBuffer_h, edgeLSendBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeARecvBuffer_h, edgeARecvBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeBRecvBuffer_h, edgeBRecvBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeCRecvBuffer_h, edgeCRecvBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeDRecvBuffer_h, edgeDRecvBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeERecvBuffer_h, edgeERecvBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeFRecvBuffer_h, edgeFRecvBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeGRecvBuffer_h, edgeGRecvBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeHRecvBuffer_h, edgeHRecvBuffer, sizeof(double) * ny * vars, accMemcpyHostToDevice);
accMemcpy(edgeIRecvBuffer_h, edgeIRecvBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeJRecvBuffer_h, edgeJRecvBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(edgeKRecvBuffer_h, edgeKRecvBuffer, sizeof(double) * nz * vars, accMemcpyHostToDevice);
accMemcpy(edgeLRecvBuffer_h, edgeLRecvBuffer, sizeof(double) * nx * vars, accMemcpyHostToDevice);
accMemcpy(xFaceUpSendBuffer_h, xFaceUpSendBuffer, sizeof(double) * ny * nz * vars, accMemcpyHostToDevice);
accMemcpy(xFaceUpRecvBuffer_h, xFaceUpRecvBuffer, sizeof(double) * ny * nz * vars, accMemcpyHostToDevice);
accMemcpy(xFaceDownSendBuffer_h, xFaceDownSendBuffer, sizeof(double) * ny * nz * vars, accMemcpyHostToDevice);
accMemcpy(xFaceDownRecvBuffer_h, xFaceDownRecvBuffer, sizeof(double) * ny * nz * vars, accMemcpyHostToDevice);
accMemcpy(yFaceUpSendBuffer_h, yFaceUpSendBuffer, sizeof(double) * nx * nz * vars, accMemcpyHostToDevice);
accMemcpy(yFaceUpRecvBuffer_h, yFaceUpRecvBuffer, sizeof(double) * nx * nz * vars, accMemcpyHostToDevice);
accMemcpy(yFaceDownSendBuffer_h, yFaceDownSendBuffer, sizeof(double) * nx * nz * vars, accMemcpyHostToDevice);
accMemcpy(yFaceDownRecvBuffer_h, yFaceDownRecvBuffer, sizeof(double) * nx * nz * vars, accMemcpyHostToDevice);
accMemcpy(zFaceUpSendBuffer_h, zFaceUpSendBuffer, sizeof(double) * nx * ny * vars, accMemcpyHostToDevice);
accMemcpy(zFaceUpRecvBuffer_h, zFaceUpRecvBuffer, sizeof(double) * nx * ny * vars, accMemcpyHostToDevice);
accMemcpy(zFaceDownSendBuffer_h, zFaceDownSendBuffer, sizeof(double) * nx * ny * vars, accMemcpyHostToDevice);
accMemcpy(zFaceDownRecvBuffer_h, zFaceDownRecvBuffer, sizeof(double) * nx * ny * vars, accMemcpyHostToDevice);

#define EDGEASENDBUFFER_M edgeASendBuffer_h
#define EDGEBSENDBUFFER_M edgeBSendBuffer_h
#define EDGECSENDBUFFER_M edgeCSendBuffer_h
#define EDGEDSENDBUFFER_M edgeDSendBuffer_h
#define EDGEESENDBUFFER_M edgeESendBuffer_h
#define EDGEFSENDBUFFER_M edgeFSendBuffer_h
#define EDGEGSENDBUFFER_M edgeGSendBuffer_h
#define EDGEHSENDBUFFER_M edgeHSendBuffer_h
#define EDGEISENDBUFFER_M edgeISendBuffer_h
#define EDGEJSENDBUFFER_M edgeJSendBuffer_h
#define EDGEKSENDBUFFER_M edgeKSendBuffer_h
#define EDGELSENDBUFFER_M edgeLSendBuffer_h
#define EDGEARECVBUFFER_M edgeARecvBuffer_h
#define EDGEBRECVBUFFER_M edgeBRecvBuffer_h
#define EDGECRECVBUFFER_M edgeCRecvBuffer_h
#define EDGEDRECVBUFFER_M edgeDRecvBuffer_h
#define EDGEERECVBUFFER_M edgeERecvBuffer_h
#define EDGEFRECVBUFFER_M edgeFRecvBuffer_h
#define EDGEGRECVBUFFER_M edgeGRecvBuffer_h
#define EDGEHRECVBUFFER_M edgeHRecvBuffer_h
#define EDGEIRECVBUFFER_M edgeIRecvBuffer_h
#define EDGEJRECVBUFFER_M edgeJRecvBuffer_h
#define EDGEKRECVBUFFER_M edgeKRecvBuffer_h
#define EDGELRECVBUFFER_M edgeLRecvBuffer_h
#define XFACEUPSENDBUFFER_M xFaceUpSendBuffer_h
#define XFACEUPRECVBUFFER_M xFaceUpRecvBuffer_h
#define XFACEDOWNSENDBUFFER_M xFaceDownSendBuffer_h
#define XFACEDOWNRECVBUFFER_M xFaceDownRecvBuffer_h
#define YFACEUPSENDBUFFER_M yFaceUpSendBuffer_h
#define YFACEUPRECVBUFFER_M yFaceUpRecvBuffer_h
#define YFACEDOWNSENDBUFFER_M yFaceDownSendBuffer_h
#define YFACEDOWNRECVBUFFER_M yFaceDownRecvBuffer_h
#define ZFACEUPSENDBUFFER_M zFaceUpSendBuffer_h
#define ZFACEUPRECVBUFFER_M zFaceUpRecvBuffer_h
#define ZFACEDOWNSENDBUFFER_M zFaceDownSendBuffer_h
#define ZFACEDOWNRECVBUFFER_M zFaceDownRecvBuffer_h

#else

#define EDGEASENDBUFFER_M edgeASendBuffer
#define EDGEBSENDBUFFER_M edgeBSendBuffer
#define EDGECSENDBUFFER_M edgeCSendBuffer
#define EDGEDSENDBUFFER_M edgeDSendBuffer
#define EDGEESENDBUFFER_M edgeESendBuffer
#define EDGEFSENDBUFFER_M edgeFSendBuffer
#define EDGEGSENDBUFFER_M edgeGSendBuffer
#define EDGEHSENDBUFFER_M edgeHSendBuffer
#define EDGEISENDBUFFER_M edgeISendBuffer
#define EDGEJSENDBUFFER_M edgeJSendBuffer
#define EDGEKSENDBUFFER_M edgeKSendBuffer
#define EDGELSENDBUFFER_M edgeLSendBuffer

#define EDGEARECVBUFFER_M edgeARecvBuffer
#define EDGEBRECVBUFFER_M edgeBRecvBuffer
#define EDGECRECVBUFFER_M edgeCRecvBuffer
#define EDGEDRECVBUFFER_M edgeDRecvBuffer
#define EDGEERECVBUFFER_M edgeERecvBuffer
#define EDGEFRECVBUFFER_M edgeFRecvBuffer
#define EDGEGRECVBUFFER_M edgeGRecvBuffer
#define EDGEHRECVBUFFER_M edgeHRecvBuffer
#define EDGEIRECVBUFFER_M edgeIRecvBuffer
#define EDGEJRECVBUFFER_M edgeJRecvBuffer
#define EDGEKRECVBUFFER_M edgeKRecvBuffer
#define EDGELRECVBUFFER_M edgeLRecvBuffer

#define XFACEUPSENDBUFFER_M xFaceUpSendBuffer
#define XFACEUPRECVBUFFER_M xFaceUpRecvBuffer
#define XFACEDOWNSENDBUFFER_M xFaceDownSendBuffer
#define XFACEDOWNRECVBUFFER_M xFaceDownRecvBuffer

#define YFACEUPSENDBUFFER_M yFaceUpSendBuffer
#define YFACEUPRECVBUFFER_M yFaceUpRecvBuffer
#define YFACEDOWNSENDBUFFER_M yFaceDownSendBuffer
#define YFACEDOWNRECVBUFFER_M yFaceDownRecvBuffer

#define ZFACEUPSENDBUFFER_M zFaceUpSendBuffer
#define ZFACEUPRECVBUFFER_M zFaceUpRecvBuffer
#define ZFACEDOWNSENDBUFFER_M zFaceDownSendBuffer
#define ZFACEDOWNRECVBUFFER_M zFaceDownRecvBuffer


#endif

  struct timespec sleepTS;
  struct timespec remainTS;
  sleepTS.tv_sec = 0;
  sleepTS.tv_nsec = sleep;
  
  struct timeval start;
  struct timeval end;

  for (int i = 0; i < repeats+100; ++i) {
    requestcount = 0;

    if (i == 100) {
      gettimeofday(&start, NULL);
    }

    if (nanosleep(&sleepTS, &remainTS) == EINTR) {
      while (nanosleep(&remainTS, &remainTS) == EINTR)
        ;
    }

    if (xFaceUp > -1) {
      MPI_Irecv(XFACEUPRECVBUFFER_M, ny * nz * vars, MPI_DOUBLE, xFaceUp, 1000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(XFACEUPSENDBUFFER_M, ny * nz * vars, MPI_DOUBLE, xFaceUp, 1000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (xFaceDown > -1) {
      MPI_Irecv(XFACEDOWNRECVBUFFER_M, ny * nz * vars, MPI_DOUBLE, xFaceDown,
                1000, MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(XFACEDOWNSENDBUFFER_M, ny * nz * vars, MPI_DOUBLE, xFaceDown,
                1000, MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (yFaceUp > -1) {
      MPI_Irecv(YFACEUPRECVBUFFER_M, nx * nz * vars, MPI_DOUBLE, yFaceUp, 2000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(YFACEUPSENDBUFFER_M, nx * nz * vars, MPI_DOUBLE, yFaceUp, 2000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (yFaceDown > -1) {
      MPI_Irecv(YFACEDOWNRECVBUFFER_M, nx * nz * vars, MPI_DOUBLE, yFaceDown,
                2000, MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(YFACEDOWNSENDBUFFER_M, nx * nz * vars, MPI_DOUBLE, yFaceDown,
                2000, MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (zFaceUp > -1) {
      MPI_Irecv(ZFACEUPRECVBUFFER_M, nx * ny * vars, MPI_DOUBLE, zFaceUp, 4000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(ZFACEUPSENDBUFFER_M, nx * ny * vars, MPI_DOUBLE, zFaceUp, 4000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (zFaceDown > -1) {
      MPI_Irecv(ZFACEDOWNRECVBUFFER_M, nx * ny * vars, MPI_DOUBLE, zFaceDown,
                4000, MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(ZFACEDOWNSENDBUFFER_M, nx * ny * vars, MPI_DOUBLE, zFaceDown,
                4000, MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeA > -1) {
      MPI_Irecv(EDGEARECVBUFFER_M, nz * vars, MPI_DOUBLE, edgeA, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEASENDBUFFER_M, nz * vars, MPI_DOUBLE, edgeA, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeB > -1) {
      MPI_Irecv(EDGEBRECVBUFFER_M, nx * vars, MPI_DOUBLE, edgeB, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEBSENDBUFFER_M, nx * vars, MPI_DOUBLE, edgeB, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeC > -1) {
      MPI_Irecv(EDGECRECVBUFFER_M, nz * vars, MPI_DOUBLE, edgeC, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGECSENDBUFFER_M, nz * vars, MPI_DOUBLE, edgeC, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeD > -1) {
      MPI_Irecv(EDGEDRECVBUFFER_M, nx * vars, MPI_DOUBLE, edgeD, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEDSENDBUFFER_M, nx * vars, MPI_DOUBLE, edgeD, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeE > -1) {
      MPI_Irecv(EDGEERECVBUFFER_M, ny * vars, MPI_DOUBLE, edgeE, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEESENDBUFFER_M, ny * vars, MPI_DOUBLE, edgeE, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeF > -1) {
      MPI_Irecv(EDGEFRECVBUFFER_M, ny * vars, MPI_DOUBLE, edgeF, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEFSENDBUFFER_M, ny * vars, MPI_DOUBLE, edgeF, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeG > -1) {
      MPI_Irecv(EDGEGRECVBUFFER_M, ny * vars, MPI_DOUBLE, edgeG, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEGSENDBUFFER_M, ny * vars, MPI_DOUBLE, edgeG, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeH > -1) {
      MPI_Irecv(EDGEHRECVBUFFER_M, ny * vars, MPI_DOUBLE, edgeH, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEHSENDBUFFER_M, ny * vars, MPI_DOUBLE, edgeH, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeI > -1) {
      MPI_Irecv(EDGEIRECVBUFFER_M, nz * vars, MPI_DOUBLE, edgeI, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEISENDBUFFER_M, nz * vars, MPI_DOUBLE, edgeI, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeJ > -1) {
      MPI_Irecv(EDGEJRECVBUFFER_M, nx * vars, MPI_DOUBLE, edgeJ, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEJSENDBUFFER_M, nx * vars, MPI_DOUBLE, edgeJ, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeK > -1) {
      MPI_Irecv(EDGEKRECVBUFFER_M, nz * vars, MPI_DOUBLE, edgeK, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGEKSENDBUFFER_M, nz * vars, MPI_DOUBLE, edgeK, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    if (edgeL > -1) {
      MPI_Irecv(EDGELRECVBUFFER_M, nx * vars, MPI_DOUBLE, edgeL, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
      MPI_Isend(EDGELSENDBUFFER_M, nx * vars, MPI_DOUBLE, edgeL, 8000,
                MPI_COMM_WORLD, &requests[requestcount++]);
    }

    MPI_Waitall(requestcount, requests, status);
    requestcount = 0;
  }

  gettimeofday(&end, NULL);

  MPI_Barrier(MPI_COMM_WORLD);

  free(edgeASendBuffer);
  free(edgeBSendBuffer);
  free(edgeCSendBuffer);
  free(edgeDSendBuffer);
  free(edgeESendBuffer);
  free(edgeFSendBuffer);
  free(edgeGSendBuffer);
  free(edgeHSendBuffer);
  free(edgeISendBuffer);
  free(edgeJSendBuffer);
  free(edgeKSendBuffer);
  free(edgeLSendBuffer);
  free(edgeARecvBuffer);
  free(edgeBRecvBuffer);
  free(edgeCRecvBuffer);
  free(edgeDRecvBuffer);
  free(edgeERecvBuffer);
  free(edgeFRecvBuffer);
  free(edgeGRecvBuffer);
  free(edgeHRecvBuffer);
  free(edgeIRecvBuffer);
  free(edgeJRecvBuffer);
  free(edgeKRecvBuffer);
  free(edgeLRecvBuffer);
  free(xFaceUpSendBuffer);
  free(xFaceUpRecvBuffer);
  free(xFaceDownSendBuffer);
  free(xFaceDownRecvBuffer);
  free(yFaceUpSendBuffer);
  free(yFaceUpRecvBuffer);
  free(yFaceDownSendBuffer);
  free(yFaceDownRecvBuffer);
  free(zFaceUpSendBuffer);
  free(zFaceUpRecvBuffer);
  free(zFaceDownSendBuffer);
  free(zFaceDownRecvBuffer);

#if defined (WITH_HIP) || defined (WITH_CUDA)
  accFree(edgeASendBuffer_h);
  accFree(edgeBSendBuffer_h);
  accFree(edgeCSendBuffer_h);
  accFree(edgeDSendBuffer_h);
  accFree(edgeESendBuffer_h);
  accFree(edgeFSendBuffer_h);
  accFree(edgeGSendBuffer_h);
  accFree(edgeHSendBuffer_h);
  accFree(edgeISendBuffer_h);
  accFree(edgeJSendBuffer_h);
  accFree(edgeKSendBuffer_h);
  accFree(edgeLSendBuffer_h);
  accFree(edgeARecvBuffer_h);
  accFree(edgeBRecvBuffer_h);
  accFree(edgeCRecvBuffer_h);
  accFree(edgeDRecvBuffer_h);
  accFree(edgeERecvBuffer_h);
  accFree(edgeFRecvBuffer_h);
  accFree(edgeGRecvBuffer_h);
  accFree(edgeHRecvBuffer_h);
  accFree(edgeIRecvBuffer_h);
  accFree(edgeJRecvBuffer_h);
  accFree(edgeKRecvBuffer_h);
  accFree(edgeLRecvBuffer_h);
  accFree(xFaceUpSendBuffer_h);
  accFree(xFaceUpRecvBuffer_h);
  accFree(xFaceDownSendBuffer_h);
  accFree(xFaceDownRecvBuffer_h);
  accFree(yFaceUpSendBuffer_h);
  accFree(yFaceUpRecvBuffer_h);
  accFree(yFaceDownSendBuffer_h);
  accFree(yFaceDownRecvBuffer_h);
  accFree(zFaceUpSendBuffer_h);
  accFree(zFaceUpRecvBuffer_h);
  accFree(zFaceDownSendBuffer_h);
  accFree(zFaceDownRecvBuffer_h);
#endif

  if (convert_position_to_rank(pex, pey, pez, pex / 2, pey / 2, pez / 2) ==
      me) {
    printf("# Results from rank: %d\n", me);

    const double timeTaken =
        (((double)end.tv_sec) + ((double)end.tv_usec) * 1.0e-6) -
        (((double)start.tv_sec) + ((double)start.tv_usec) * 1.0e-6);
    const double bytesXchng =
        ((double)(xFaceUp > -1 ? sizeof(double) * ny * nz * 2 * vars : 0)) +
        ((double)(xFaceDown > -1 ? sizeof(double) * ny * nz * 2 * vars : 0)) +
        ((double)(yFaceUp > -1 ? sizeof(double) * nx * nz * 2 * vars : 0)) +
        ((double)(yFaceDown > -1 ? sizeof(double) * nx * nz * 2 * vars : 0)) +
        ((double)(zFaceUp > -1 ? sizeof(double) * nx * ny * 2 * vars : 0)) +
        ((double)(zFaceDown > -1 ? sizeof(double) * nx * ny * 2 * vars : 0)) +
        ((double)(edgeA > -1 ? sizeof(double) * nz * 2 * vars : 0)) +
        ((double)(edgeB > -1 ? sizeof(double) * nx * 2 * vars : 0)) +
        ((double)(edgeC > -1 ? sizeof(double) * nz * 2 * vars : 0)) +
        ((double)(edgeD > -1 ? sizeof(double) * nx * 2 * vars : 0)) +
        ((double)(edgeE > -1 ? sizeof(double) * ny * 2 * vars : 0)) +
        ((double)(edgeF > -1 ? sizeof(double) * ny * 2 * vars : 0)) +
        ((double)(edgeG > -1 ? sizeof(double) * ny * 2 * vars : 0)) +
        ((double)(edgeH > -1 ? sizeof(double) * ny * 2 * vars : 0)) +
        ((double)(edgeI > -1 ? sizeof(double) * nz * 2 * vars : 0)) +
        ((double)(edgeJ > -1 ? sizeof(double) * nx * 2 * vars : 0)) +
        ((double)(edgeK > -1 ? sizeof(double) * nz * 2 * vars : 0)) +
        ((double)(edgeL > -1 ? sizeof(double) * nx * 2 * vars : 0));

    printf("# %20s %20s %20s\n", "Time", "KBytesXchng/Rank-Max", "MB/S/Rank");
    printf("  %20.6f %20.4f %20.4f\n", timeTaken, bytesXchng / 1024.0,
           (bytesXchng / 1024.0) / timeTaken);
  }

  MPI_Finalize();
}
