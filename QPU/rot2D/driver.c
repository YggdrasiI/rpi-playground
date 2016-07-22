#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <sys/time.h>
#include <math.h>
#include <assert.h>

#include "mailbox.h"
#include "qpu.h"

#define NUM_QPUS        1
#define MAX_CODE_SIZE   8192

// Uniform stores:
// 1. NumQPU()
// 2. Number of elements
// 3. sin of rotation angle
// 4. cos of rotation angle
// 5. Input address of x vector
// 6. Input address of y vector
// 7. Output address of x' vector
// 8. Output address of y' vector
#define NUM_UNIFORMS    8

//Number of processed (x,y) pairs. Should be a multiple of 16.
//#define NUM_ELEMENTS    (16*12) 
#define NUM_ELEMENTS    20

static unsigned int qpu_code[MAX_CODE_SIZE];

struct memory_map {
    unsigned int code[MAX_CODE_SIZE];
    unsigned int uniforms[NUM_QPUS][NUM_UNIFORMS];
    unsigned int msg[NUM_QPUS][2];
    unsigned int results[2][NUM_ELEMENTS];  // result buffer for the QPU to
                                            // write into
};


int loadShaderCode(const char *fname, unsigned int* buffer, int len)
{
    FILE *in = fopen(fname, "r");
    if (!in) {
        fprintf(stderr, "Failed to open %s.\n", fname);
        exit(0);
    }

    size_t items = fread(buffer, sizeof(unsigned int), len, in);
    fclose(in);

    return items;
}

void init_input(size_t n, float *x, float *y){
    // Memory structure xxxxx…, yyyyy…
    float a = 0.0f;
    float b = 5.0f;
    while( n > 0 ){
        n--;
        *x++ = a;
        *y++ = b;
        a += 0.1f;
        b -= 0.1f;
    }
}

void print_output(size_t n, float *x_out, float *y_out){
    // Memory structure xxxxx…, yyyyy…
 
    // Regen input to compare.
    float a[n]; float b[n];
    init_input(n, a, b);
    float *x_in = a; float *y_in = b;

    while( n > 0 ){
        n--;
        printf("(%4.4f,%4.4f) => (%4.4f,%4.4f)\t\t(%d,%d)\n",
                *x_in, *y_in, *x_out, *y_out, *((int*)x_out), *((int*)y_out));
        x_in++; y_in++; x_out++; y_out++;
    }
}

void init_input_tuples(size_t n, float *xy){
    // Memory structure xy,xy,xy,…
    float a[n]; float b[n];
    init_input(n, a, b);
    float *x_in = a; float *y_in = b;
    
    while( n > 0 ){
        n--;
        *xy++ = *x_in++;
        *xy++ = *y_in++;
    }
}

void print_output_tuple(size_t n, float *xy_out){
    // Memory structure xy,xy,xy,…
    
    // Regen input to compare.
    float a[n]; float b[n];
    init_input(n, a, b);
    size_t m = n;

    while( m > 0 ){
        m--;
        a[m] = xy_out[2*m];
        b[m] = xy_out[2*m+1];
    }
    print_output(n, a, b);
}



int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <code .bin> <val>\n", argv[0]);
        return 0;
    }

    const double rotation_angle = M_PI;
    const float rot_sin = sin(rotation_angle);
    const float rot_cos = cos(rotation_angle);

    int code_words = loadShaderCode(argv[1], qpu_code, MAX_CODE_SIZE);

    printf("Loaded %d bytes of code from %s ...\n", code_words * sizeof(unsigned), argv[1]);

    int mb = mbox_open();

    struct GPU_FFT_HOST host;
    if (gpu_fft_get_host_info(&host)){
        fprintf(stderr, "QPU fetch of host information (Rpi version, etc.) failed.\n");
        return -5;
    }

    if (qpu_enable(mb, 1)) {
        fprintf(stderr, "QPU enable failed.\n");
        return -1;
    }
    printf("QPU enabled.\n");

    unsigned uniform_val = atoi(argv[2]);
    printf("Uniform value = %d\n", uniform_val);

    unsigned size = 1024 * 1024;
    unsigned handle = mem_alloc(mb, size, 4096, host.mem_flg);
    if (!handle) {
        fprintf(stderr, "Unable to allocate %d bytes of GPU memory", size);
        return -2;
    }

    volatile unsigned *peri = (volatile unsigned *) mapmem(host.peri_addr, host.peri_size);
    if (!peri) {
        mem_free(mb, handle);
        qpu_enable(mb, 0);
        return -4;
    }

    unsigned ptr = mem_lock(mb, handle);
    void *arm_ptr = mapmem(BUS_TO_PHYS(ptr + host.mem_map), size);

    struct memory_map *arm_map = (struct memory_map *)arm_ptr;
    memset(arm_map, 0x0, sizeof(struct memory_map));

    //init_input( NUM_ELEMENTS, (float*)arm_map->results,
    //        ((float*)arm_map->results)+NUM_ELEMENTS);
    init_input_tuples( NUM_ELEMENTS, (float*)arm_map->results);

    unsigned vc_uniforms = ptr + offsetof(struct memory_map, uniforms);
    unsigned vc_code = ptr + offsetof(struct memory_map, code);
    unsigned vc_msg = ptr + offsetof(struct memory_map, msg);
    unsigned vc_results = ptr + offsetof(struct memory_map, results);
    memcpy(arm_map->code, qpu_code, code_words * sizeof(unsigned int));
    for (int i=0; i < NUM_QPUS; i++) {
        int uni_arg = 0;
        arm_map->uniforms[i][uni_arg++] = NUM_QPUS;
        arm_map->uniforms[i][uni_arg++] = *((unsigned int*)&rot_sin);
        arm_map->uniforms[i][uni_arg++] = *((unsigned int*)&rot_cos);
        arm_map->uniforms[i][uni_arg++] = NUM_ELEMENTS;
        // Use output positions as input, too.
        arm_map->uniforms[i][uni_arg++] = vc_results + i * 16 * sizeof(unsigned);
        arm_map->uniforms[i][uni_arg++] = vc_results + (NUM_ELEMENTS + i * 16 )* sizeof(unsigned);
        // Output pointers only for i=0 used
        arm_map->uniforms[i][uni_arg++] = vc_results + i * 16 * sizeof(unsigned);
        arm_map->uniforms[i][uni_arg++] = vc_results + (NUM_ELEMENTS + i * 16 )* sizeof(unsigned);
        assert(uni_arg == NUM_UNIFORMS);

        arm_map->msg[i][0] = vc_uniforms + i * NUM_UNIFORMS * sizeof(unsigned);
        arm_map->msg[i][1] = vc_code;
    }

    unsigned ret = execute_qpu(mb, NUM_QPUS, vc_msg, GPU_FFT_NO_FLUSH, GPU_FFT_TIMEOUT);

    // check the results!
    //print_output( NUM_ELEMENTS, (float*)arm_map->results,
    //        ((float*)arm_map->results)+NUM_ELEMENTS);
    print_output_tuple( NUM_ELEMENTS, (float*)arm_map->results);

    printf("Cleaning up.\n");
    unmapmem(arm_ptr, size);
    unmapmem((void*)host.peri_addr, host.peri_size);
    mem_unlock(mb, handle);
    mem_free(mb, handle);
    qpu_enable(mb, 0);
    printf("Done.\n");
}
