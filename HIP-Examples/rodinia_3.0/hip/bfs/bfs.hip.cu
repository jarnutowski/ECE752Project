#include "hip/hip_runtime.h"
/***********************************************************************************
  Implementing Breadth first search on CUDA using algorithm given in HiPC'07
  paper "Accelerating Large Graph Algorithms on the GPU using CUDA"

  Copyright (c) 2008 International Institute of Information Technology - Hyderabad. 
  All rights reserved.

  Permission to use, copy, modify and distribute this software and its documentation for 
  educational purpose is hereby granted without fee, provided that the above copyright 
  notice and this permission notice appear in all copies of this software and that you do 
  not sell the software.

  THE SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTY OF ANY KIND,EXPRESS, IMPLIED OR 
  OTHERWISE.

  Created by Pawan Harish.
 ************************************************************************************/
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#ifdef __CUDA_CC__
#include "cuda.h"
#endif
#include <sys/time.h>

#define MAX_THREADS_PER_BLOCK 512

#define PROFILING 1
#ifdef PROFILING
#include "RDTimer.h"
#endif

int no_of_nodes;
int edge_list_size;
FILE *fp;

//Structure to hold a node information
struct Node
{
	int starting;
	int no_of_edges;
};

#include "kernel.hip.cu"
#include "kernel2.hip.cu"

void BFSGraph(int argc, char** argv);

////////////////////////////////////////////////////////////////////////////////
// Main Program
////////////////////////////////////////////////////////////////////////////////
int main( int argc, char** argv) 
{
	no_of_nodes=0;
	edge_list_size=0;
	BFSGraph( argc, argv);
}

void Usage(int argc, char**argv){

fprintf(stderr,"Usage: %s <input_file>\n", argv[0]);

}
////////////////////////////////////////////////////////////////////////////////
//Apply BFS on a Graph using CUDA
////////////////////////////////////////////////////////////////////////////////
void BFSGraph( int argc, char** argv) 
{
	
    char *input_f;
	if(argc!=2){
	Usage(argc, argv);
	exit(0);
	}
	
	struct timeval start_time, end_time,start_time_kernel, end_time_kernel;
/* overall time - start */
#ifdef PROFILING
	float alloc_t, cpu_to_gpu_t,kernel_t,gpu_to_cpu_t,overall_cpu_t;
        RDTimerCPU* rdtimerOverallCpu = new RDTimerCPU();
        rdtimerOverallCpu->Reset("Overall CPU Time");
        rdtimerOverallCpu->Start();
#endif	
	input_f = argv[1];
	printf("Reading File\n");
	//Read in Graph from a file
	fp = fopen(input_f,"r");
	if(!fp)
	{
		printf("Error Reading graph file\n");
		return;
	}

	int source = 0;

	fscanf(fp,"%d",&no_of_nodes);

	int num_of_blocks = 1;
	int num_of_threads_per_block = no_of_nodes;

	//Make execution Parameters according to the number of nodes
	//Distribute threads across multiple Blocks if necessary
	if(no_of_nodes>MAX_THREADS_PER_BLOCK)
	{
		num_of_blocks = (int)ceil(no_of_nodes/(double)MAX_THREADS_PER_BLOCK); 
		num_of_threads_per_block = MAX_THREADS_PER_BLOCK; 
	}

	// allocate host memory
	Node* h_graph_nodes = (Node*) malloc(sizeof(Node)*no_of_nodes);
	bool *h_graph_mask = (bool*) malloc(sizeof(bool)*no_of_nodes);
	bool *h_updating_graph_mask = (bool*) malloc(sizeof(bool)*no_of_nodes);
	bool *h_graph_visited = (bool*) malloc(sizeof(bool)*no_of_nodes);

	int start, edgeno;   
	// initalize the memory
	for( unsigned int i = 0; i < no_of_nodes; i++) 
	{
		fscanf(fp,"%d %d",&start,&edgeno);
		h_graph_nodes[i].starting = start;
		h_graph_nodes[i].no_of_edges = edgeno;
		h_graph_mask[i]=false;
		h_updating_graph_mask[i]=false;
		h_graph_visited[i]=false;
	}

	//read the source node from the file
	fscanf(fp,"%d",&source);
	source=0;

	//set the source node as true in the mask
	h_graph_mask[source]=true;
	h_graph_visited[source]=true;

	fscanf(fp,"%d",&edge_list_size);

	int id,cost;
	int* h_graph_edges = (int*) malloc(sizeof(int)*edge_list_size);
	for(int i=0; i < edge_list_size ; i++)
	{
		fscanf(fp,"%d",&id);
		fscanf(fp,"%d",&cost);
		h_graph_edges[i] = id;
	}

	if(fp)
		fclose(fp);    

	printf("Read File\n");

        // allocate mem for the result on host side
        int* h_cost = (int*) malloc( sizeof(int)*no_of_nodes);
        for(int i=0;i<no_of_nodes;i++)
                h_cost[i]=-1;
        h_cost[source]=0;
	
	/* start time */
	gettimeofday(&start_time, NULL);

/* malloc time-start */ 
#ifdef PROFILING
        SimplePerfSerializer* serializeTime = new SimplePerfSerializer( argv[0] );

        RDTimerCPU* rdtimercpu = new RDTimerCPU();

        rdtimercpu->Reset("Malloc Time");
        rdtimercpu->Start();
#endif	
	//Copy the Node list to device memory
	Node* d_graph_nodes;
	hipMalloc( (void**) &d_graph_nodes, sizeof(Node)*no_of_nodes) ;

	//Copy the Edge List to device Memory
	int* d_graph_edges;
	hipMalloc( (void**) &d_graph_edges, sizeof(int)*edge_list_size) ;
	
	//Copy the Mask to device memory
        bool* d_graph_mask;
	hipMalloc( (void**) &d_graph_mask, sizeof(bool)*no_of_nodes) ;

	bool* d_updating_graph_mask;
	hipMalloc( (void**) &d_updating_graph_mask, sizeof(bool)*no_of_nodes) ;

	//Copy the Visited nodes array to device memory
	bool* d_graph_visited;
	hipMalloc( (void**) &d_graph_visited, sizeof(bool)*no_of_nodes) ;

	// allocate device memory for result
	int* d_cost;
	hipMalloc( (void**) &d_cost, sizeof(int)*no_of_nodes);

	//make a bool to check if the execution is over
	bool *d_over;
	hipMalloc( (void**) &d_over, sizeof(bool));

// copying to GPU

/* malloc time-stop, cpu-gpu transfer start */ 
#ifdef PROFILING
        alloc_t = rdtimercpu->Stop();
        serializeTime->Serialize(rdtimercpu);
        rdtimercpu->Reset("CPU to GPU Transfer Time");
        rdtimercpu->Start();
#endif
 
// nodelist
	hipMemcpy( d_graph_nodes, h_graph_nodes, sizeof(Node)*no_of_nodes, hipMemcpyHostToDevice) ;
//edgelist	
	hipMemcpy( d_graph_edges, h_graph_edges, sizeof(int)*edge_list_size, hipMemcpyHostToDevice) ;
//mask
	hipMemcpy( d_graph_mask, h_graph_mask, sizeof(bool)*no_of_nodes, hipMemcpyHostToDevice) ;
	hipMemcpy( d_updating_graph_mask, h_updating_graph_mask, sizeof(bool)*no_of_nodes, hipMemcpyHostToDevice) ;
// visited nodes 
	hipMemcpy( d_graph_visited, h_graph_visited, sizeof(bool)*no_of_nodes, hipMemcpyHostToDevice) ;
// device memory for result 
	hipMemcpy( d_cost, h_cost, sizeof(int)*no_of_nodes, hipMemcpyHostToDevice) ;

	printf("Copied Everything to GPU memory\n");

	// setup execution parameters
	dim3  grid( num_of_blocks, 1, 1);
	dim3  threads( num_of_threads_per_block, 1, 1);

	int k=0;
	printf("Start traversing the tree\n");
	bool stop;
	//Call the Kernel untill all the elements of Frontier are not false
	
	/* start time */
	gettimeofday(&start_time_kernel, NULL);
/*cpu-gpu transfer-stop, kernel exec-start */
#ifdef PROFILING
    cpu_to_gpu_t =  rdtimercpu->Stop();
    serializeTime->Serialize(rdtimercpu);
    rdtimercpu->Reset("COMPUTE:Kernel Execution Time");
    //hipDeviceSynchronize();
    rdtimercpu->Start();
#endif
	
	do
	{
		//if no thread changes this value then the loop stops
		stop=false;
		hipMemcpy( d_over, &stop, sizeof(bool), hipMemcpyHostToDevice) ;
		hipLaunchKernelGGL(Kernel, dim3(grid), dim3(threads ), 0, 0,  d_graph_nodes, d_graph_edges, d_graph_mask, d_updating_graph_mask, d_graph_visited, d_cost, no_of_nodes);
		// check if kernel execution generated and error
		

		hipLaunchKernelGGL(Kernel2, dim3(grid), dim3(threads ), 0, 0,  d_graph_mask, d_updating_graph_mask, d_graph_visited, d_over, no_of_nodes);
		// check if kernel execution generated and error
		

		hipMemcpy( &stop, d_over, sizeof(bool), hipMemcpyDeviceToHost) ;
		k++;
	}
	while(stop);

/* kernel exec-stop, gpu-cpu transfer-start */
#ifdef PROFILING
    kernel_t = rdtimercpu->Stop();
    serializeTime->Serialize(rdtimercpu);
    rdtimercpu->Reset("GPU to CPU Transfer Time");
    rdtimercpu->Start();
#endif
        /* end time */
        gettimeofday(&end_time_kernel, NULL);

	printf("Kernel Executed %d times\n",k);

	// copy result from device to host
	hipMemcpy( h_cost, d_cost, sizeof(int)*no_of_nodes, hipMemcpyDeviceToHost) ;
        
/* gpu-cpu transfer- stop */ 
#ifdef PROFILING        
    gpu_to_cpu_t= rdtimercpu->Stop();
    serializeTime->Serialize(rdtimercpu);
#endif
	/* end time */
        gettimeofday(&end_time, NULL);

	//Store the result into a file
	FILE *fpo = fopen("result.txt","w");
	for(int i=0;i<no_of_nodes;i++)
		fprintf(fpo,"%d) cost:%d\n",i,h_cost[i]);
	fclose(fpo);
	printf("Result stored in result.txt\n");

	/* printing runtime including mem alloc and copying */
/*	printf("Runtime on GPU including memory allocations: %.4lf s\n", end_time.tv_sec + end_time.tv_usec / 1000000.0 - start_time.tv_sec - start_time.tv_usec / 1000000.0);*/

	/* printing runtime of kernel execution */
       /* printf("Runtime on GPU for kernel execution: %.4lf s\n", end_time_kernel.tv_sec + end_time_kernel.tv_usec / 1000000.0 - start_time_kernel.tv_sec - start_time_kernel.tv_usec / 1000000.0);*/	
	
/* over all stop print all times delete timers */
#ifdef PROFILING    
    overall_cpu_t =  rdtimerOverallCpu->Stop();
    serializeTime->Serialize(rdtimerOverallCpu);
      printf("time CPU to GPU memory copy = %lfs\n", cpu_to_gpu_t);
      printf("time GPU to CPU memory copy back = %lfs\n", gpu_to_cpu_t);
      printf("time GPU malloc = %lfs\n", alloc_t);
      printf("time kernel = %lfs\n", kernel_t);
      printf("Overall CPU time = %lfs\n", overall_cpu_t);
      
          delete rdtimercpu;
          delete serializeTime;
          delete rdtimerOverallCpu;

 #endif
	// cleanup memory
	free( h_graph_nodes);
	free( h_graph_edges);
	free( h_graph_mask);
	free( h_updating_graph_mask);
	free( h_graph_visited);
	free( h_cost);
	hipFree(d_graph_nodes);
	hipFree(d_graph_edges);
	hipFree(d_graph_mask);
	hipFree(d_updating_graph_mask);
	hipFree(d_graph_visited);
	hipFree(d_cost);
}
