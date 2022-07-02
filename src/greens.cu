// # include "helper_math.h" // vector math

// # include "sizes.cu" // size defines

# include "interpd.cu" // samplers using constant sizing

// # include "half2_math.h" // vector math for half types only 

__global__ void greensf(float2 * __restrict__ y, 
    const float * __restrict__ Pi, const float * __restrict__ a, 
    const float * __restrict__ Pr, const float * __restrict__ Pv, 
    const float2 * __restrict__ x, const float s0,
	const float t0, const float fs, const float cinv,
    const int * E, const int iflag
    ) {

    // get starting index of this scatterer
    const size_t s = threadIdx.x + blockIdx.x * blockDim.x; // time 
    const size_t n = threadIdx.y + blockIdx.y * blockDim.y; // rx
    const size_t m = threadIdx.z + blockIdx.z * blockDim.z; // tx

    // reinterpret inputs as vector pointers (makes loading faster and indexing easier)
    const float3 * pi = reinterpret_cast<const float3*>(Pi); // 3 x I
    const float3 * pr = reinterpret_cast<const float3*>(Pr); // 3 x N x E
    const float3 * pv = reinterpret_cast<const float3*>(Pv); // 3 x M x E

    // rename for readability
    const size_t N = QUPS_N, I = QUPS_I, S = QUPS_S, M = QUPS_M;//, T = QUPS_T;
    // rxs, num scat, output time size, txs, kernel time size, 
    // S is size of output, T is size of input kernel, I the number of scats
    
    // temp vars
    const float ts = ((float)s/fs) + s0; // compute the time index for this thread
    const float2 zero_v = make_float2(0.0f); // OOB value
    float r, tau;
    float2 val = zero_v;

    // if valid scat, for each tx/rx
    if(s < S){
        #pragma unroll
        for(size_t i = 0; i < I; ++i){ // for each scatterer
            # pragma unroll 
            for(size_t me = 0; me < E[1]; ++me){ // for each tx sub-aperture
                # pragma unroll 
                for(size_t ne = 0; ne < E[0]; ++ne){ // for each rx sub-aperture

                    // 2-way path distance
                    r = cinv * (length(pi[i] - pr[n + ne*N]) + length(pi[i] - pv[m + me*M])); // (virtual) transmit to pixel vector
                    
                    // get kernel delay for the scatterer
                    tau = ts - r + t0;
                    
                    // sample the kernel and add to the signal at this time
                    val += a[i] * samplef(x, fs*tau, iflag, zero_v); // out of bounds: extrap 0            
                }
            }
        }

        // output signal when all scatterers and sub-apertures are sampled
         y[s + n*S + m*N*S] = val;
    }
}
