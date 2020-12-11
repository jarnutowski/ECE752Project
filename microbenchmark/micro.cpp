#include <stdio.h>
#include "hip/hip_runtime.h"

#define CHECK(cmd) \
{\
	hipError_t error= cmd;\
	if (error != hipSuccess) { \
	  fprintf(stderr, "error: '%s'($d) at %s:%d\n", hipGetErrorString(error), error, __FILE__, __LINE__); \
	  exit(EXIT_FAILURE);\
	}\
}

// set up a RAW then WAW hazard and expect scoreboard checks for this

template <typename T>
__global__ void
simple_test(T *C, const T *A, T *B, size_t N)
{
	size_t offset = (hipBlockIdx_x * hipBlockDim_x + hipThreadIdx_x);

	B[offset] = A[offset] + A[offset];
	C[offset] = B[offset] + A[offset];
	C[offset] = A[offset] + A[offset];
}

int main(int argc, char *argv[])
{
#ifdef DGPU
	int *A, *B, *C;
#endif
	int *A_n, *B_n, *C_n;
	size_t N = 1;
	size_t Nbytes = N * sizeof(int);
	hipDeviceProp_t props;
	CHECK(hipGetDeviceProperties(&props, 0/*deviceID*/));
	printf ("info: running on device %s\n", props.name);
	#ifdef __HIPPLATFORM_HCC__
	  printf ("info: architecture on AMD GPU device is: %d\n", props.gcnArch);
	#endif
	printf ("info: allocate host mem (%6.2f MB)\n", 2*Nbytes/1024.0/1024.0);
	A_n = (int*)malloc(Nbytes);
	CHECK(A_n == 0 ? hipErrorMemoryAllocation : hipSuccess );
	B_n = (int*)malloc(Nbytes);
	CHECK(B_n == 0 ? hipErrorMemoryAllocation : hipSuccess );
	C_n = (int*)malloc(Nbytes);
	CHECK(C_n == 0 ? hipErrorMemoryAllocation : hipSuccess );

	A_n[0] = 3;

#ifdef DGPU
	printf ("info: allocate device mem (%6.2f MB)\n", 2*Nbytes/1024.0/1024.0);
	CHECK(hipMalloc(&A, Nbytes));
	CHECK(hipMalloc(&B, Nbytes));
	CHECK(hipMalloc(&C, Nbytes));

	printf ("info: copy Host2Device\n");
	CHECK ( hipMemcpy(A, A_n, Nbytes, hipMemcpyHostToDevice));
#endif

	const unsigned blocks = 1;
	const unsigned threadsPerBlock = 1;

	printf ("info: launch 'simple_test' kernel\n");
#ifdef DGPU
	hipLaunchKernelGGL(simple_test, dim3(blocks), dim3(threadsPerBlock), 0, 0, C, A, B, N);

	printf ("info: copy Device2Host\n");
	CHECK ( hipMemcpy(C_n, C, Nbytes, hipMemcpyDeviceToHost));
	CHECK ( hipMemcpy(B_n, B, Nbytes, hipMemcpyDeviceToHost));
#else
	hipLaunchKernelGGL(simple_test, dim3(blocks), dim3(threadsPerBlock), 0, 0, C_n, A_n, B_n, N);
#endif
	printf ("info: check result\n");
	if(B_n[0] != A_n[0] + A_n[0]) {
		CHECK(hipErrorUnknown);
	}
	if(C_n[0] != A_n[0] + A_n[0]) {
		CHECK(hipErrorUnknown);
	}
	printf ("PASSED!\n");
	return 0;
}


