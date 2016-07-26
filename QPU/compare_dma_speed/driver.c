/*
   Test if and how the collection of several DMA writes into one
   single command speed up the transfer.
   The first variant writes M words (4 bytes) in M/16 steps.
   The second variant writes M words in M/16/8 steps.
   The third variant uses halve of VPM and writes M words in M/16/32 steps.

   If you select loop_vdm_and_dma_write.asm (see Makefile), the QPU also
   writes into the VPM during the loop.
   */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <sys/time.h>

#include "mailbox.h"
#include "qpu.h"

#define NUM_QPUS        1
#define MAX_CODE_SIZE   8192

/* Allocated space for result of DMA transfers.
 * Multiple of 16 and at least enough for one full VPM transfer.
 */
#define N  (64 * 16)
/* Number of DMA transfered words at all.
 */
#define M (10000 * N)

#define TRANSFER_DATA(M) ((double)M * sizeof(int) / 1E6)
#define TRANSFER_RATE(M, TIMEVAL) ( \
        (TRANSFER_DATA(M)) / (TIMEVAL.tv_sec * 1.0 + TIMEVAL.tv_usec * 1E-6) \
        )

static unsigned int qpu_code[MAX_CODE_SIZE];

struct memory_map {
    unsigned int code[MAX_CODE_SIZE];
    unsigned int uniforms[NUM_QPUS][3];     // 2 parameters per QPU
                                            // first address is the input value
                                            // for the program to add to
                                            // second is the address of the
                                            // result buffer
    unsigned int msg[NUM_QPUS][2];
    unsigned int results[NUM_QPUS][N];     // result buffer for the QPU to
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

int main(int argc, char **argv)
{
    //Timestamps
    timeval tvStart, tvEnd, tvDiff[3];
    unsigned units[3] = {1, 8, 32};
    unsigned ret[3] = {-1, -1, -1};

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

    // First run. Write one unit (16 words) in each dma call.
    for (int i=0; i < NUM_QPUS; i++) {
        arm_map->uniforms[i][0] = M;
        arm_map->uniforms[i][1] = units[0];
        arm_map->uniforms[i][2] = vc_results + i * sizeof(unsigned) * 16;
        arm_map->msg[i][0] = vc_uniforms + i * sizeof(unsigned) * 2;
        arm_map->msg[i][1] = vc_code;
    }

    for ( int j=0; j<3 ; j++){
        for (int i=0; i < NUM_QPUS; i++) {
            arm_map->uniforms[i][1] = units[j];
        }

        gettimeofday(&tvStart, NULL);
        ret[j] = execute_qpu(mb, NUM_QPUS, vc_msg, GPU_FFT_NO_FLUSH, 15*GPU_FFT_TIMEOUT);
        gettimeofday(&tvEnd, NULL);
        timersub(&tvEnd, &tvStart, &tvDiff[j]);

        // Debugging, check results.
        size_t num_expected_result_match = 0;
        for (int i=0; i < N; i++) {
            if( arm_map->results[0][i] == i%(16*units[j]) ) ++num_expected_result_match;
        }
        printf("Run(%2u) Transfered data match on %d of %d positions.\n",
                units[j], num_expected_result_match, N);
    }

    // Check the results
    if( N < 130 ){
        for (int i=0; i < N; i++) {
            printf("word %d: 0x%08x\n", i,  arm_map->results[0][i]);
        }
    }else{
        for (int i=0; i < 8; i++) {
            printf("word %d: 0x%08x\n", i, (int) arm_map->results[0][i]);
        }
        printf("[...]\n");
        printf("word %d: 0x%08x\n", N-1, (int) arm_map->results[0][N-1]);
    }

    printf("\nExit flags: %u %u %u\t\tTransfered data: %4.3f MB\n",
            ret[0], ret[1], ret[2], TRANSFER_DATA(M));
    for( int i=0; i<3; i++){
    printf("Time(%2d): %ld.%06lds\t\tRate %4.3f MB/s\n",
            units[i], tvDiff[i].tv_sec, tvDiff[i].tv_usec,
            TRANSFER_RATE(M, tvDiff[i])
            );
    }

    printf("Cleaning up.\n");
    unmapmem(arm_ptr, size);
    unmapmem((void*)host.peri_addr, host.peri_size);
    mem_unlock(mb, handle);
    mem_free(mb, handle);
    qpu_enable(mb, 0);
    printf("Done.\n");
}
