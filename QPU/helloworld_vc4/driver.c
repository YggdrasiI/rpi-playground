#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <sys/time.h>

#include "mailbox.h"
#include "qpu.h"

#define NUM_QPUS        12
#define MAX_CODE_SIZE   8192

static unsigned int qpu_code[MAX_CODE_SIZE];

struct memory_map {
    unsigned int code[MAX_CODE_SIZE];
    unsigned int uniforms[NUM_QPUS][2];     // 2 parameters per QPU
                                            // first address is the input value
                                            // for the program to add to
                                            // second is the address of the
                                            // result buffer
    unsigned int msg[NUM_QPUS][2];
    unsigned int results[NUM_QPUS][16];     // result buffer for the QPU to
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

/* Uniform value for qpu 
 * Note: Sometimes, I've got the wrong
 * uniform on QPU X (it uses the value from X+1) in some of the four
 * multiplexed runs.
 */
unsigned int uniform_map(int i ){
    return (unsigned int) i;
}
/* For test if result is ok. */
unsigned int cpu_result(int i, int j){
    return uniform_map(i)+ 0x1234;
}
// Returns zero if ok
unsigned int cpu_result_probe(int i, int j, unsigned int qpu_result){
    return ( cpu_result(i,j) - qpu_result );
}

/* QPU-code add on each QPU an uniform with a constant and returns it
 * separatly by DMA.
 * The results will be compared with a probe on the cpu.
 */
int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <code .bin> <val>\n", argv[0]);
        return 0;
    }
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
    // assert arm_ptr ...

    struct memory_map *arm_map = (struct memory_map *)arm_ptr;
    memset(arm_map, 0x0, sizeof(struct memory_map));
    unsigned vc_uniforms = ptr + offsetof(struct memory_map, uniforms);
    unsigned vc_code = ptr + offsetof(struct memory_map, code);
    unsigned vc_msg = ptr + offsetof(struct memory_map, msg);
    unsigned vc_results = ptr + offsetof(struct memory_map, results);
    memcpy(arm_map->code, qpu_code, code_words * sizeof(unsigned int));
    for (int i=0; i < NUM_QPUS; i++) {
        arm_map->uniforms[i][0] = uniform_map(i);//uniform_val;
        arm_map->uniforms[i][1] = vc_results + i * sizeof(unsigned) * 16;
        arm_map->msg[i][0] = vc_uniforms + i * sizeof(arm_map->uniforms[0]);
        arm_map->msg[i][1] = vc_code;
    }

    unsigned ret = execute_qpu(mb, NUM_QPUS, vc_msg, GPU_FFT_NO_FLUSH, GPU_FFT_TIMEOUT);

    // check the results!
    for (int i=0; i < NUM_QPUS; i++) {
        printf("QPU %2d: ", i);
        unsigned int qpu_i0 = arm_map->results[i][0];
        printf("word %d: %8u\n", 0, arm_map->results[i][0]);
        for (int j=0; j < 16; j++) {
            if( cpu_result_probe(i,j, arm_map->results[i][0] ) ){
                printf("Error on word %d: expect: %8u  get: %8u\n",
                        j, arm_map->results[i][j],
                        cpu_result(i,j));
            }
        }
    }

    printf("Cleaning up.\n");
    unmapmem(arm_ptr, size);
    unmapmem((void*)host.peri_addr, host.peri_size);
    mem_unlock(mb, handle);
    mem_free(mb, handle);
    qpu_enable(mb, 0);
    printf("Done.\n");
}
