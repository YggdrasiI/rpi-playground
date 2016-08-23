# Rotation of (x,y)-vectors by fixed angle (for vc4asm compiler)

#############################################################
# For Input
.set ra_x1,         ra3
.set rb_y1,         rb3
.set ra_x2,         ra4
.set rb_y2,         rb4

# Working registers
.set ra_tmp0,         ra10
.set rb_tmp0,         rb10
.set ra_tmp1,         ra11
.set rb_tmp1,         rb11
.set ra_tmp2,         ra12
.set rb_tmp2,         rb12

# Setup
.set ra_load_idx,       ra5
.set rb_stride,         rb5
.set ra_instQPU,        ra24 # always = num_qpu?!

.set ra_vpm_setup0,     ra26
.set rb_vpm_setup1,     rb26
.set ra_vdm_setup0,     ra26
.set rb_vdm_setup1,     rb25


#############################################################
# Uniforms
.set ra_numQPU,         ra29
.set rb_N,              rb29
.set ra_sin,            ra28
.set rb_cos,            rb28
.set ra_addr_in,        ra27
.set rb_addr_out,       rb27


#############################################################
## Push two texture request commands.
# Assumes that the texture unit is already setuped.
#     Pseudocode:
#       gather_texture(cur_elem_idx.x) // 4 bytes
#       gather_texture(cur_elem_idx.y) // next 4 bytes
#       cur_elem_idx = cur_elem_idx + stride
#
.macro read_lin, stride
    add ra_load_idx, ra_load_idx, stride; mov r0, ra_load_idx

    shl r0, r0, 3
    add r1, r0, 4

    add t0s, ra_addr_in, r0 # x
    add t0s, ra_addr_in, r1 # y
.endm

# Gather (x,y) and use the three cyles after the
# branch to receive textures in r0 and r1.
.macro load_lin, stride, call
    read_lin stride
    brr rb_N, call
    nop;        ldtmu0
    mov r0, r4; ldtmu0                                                                    
    mov r1, r4                                                                            
.endm


#############################################################

#############################################################
## Read uniforms
#
# Uniform read order
# 1. NumQPU()
# 2. Number of elements
# 3. sin of rotation angle
# 4. cos of rotation angle
# 5. Input address of x vector
# 6. Input address of y vector //ignore this
# 7. Output address of x' vector
# 8. Output address of y' vector //ignore this

mov ra_numQPU, unif
mov rb_N, unif
mov ra_sin, unif
mov rb_cos, unif
mov ra_addr_in, unif
mov -, unif
mov rb_addr_out, unif
mov -, unif

#############################################################
## Setup

# Use one qpu instance for test.
mov ra_instQPU, qpu_num
shl rb_stride, ra_numQPU, 4 # 16 * NumQPU
# Start at block index 0+16*instQPU and set
# read addresses to p, p+8, …, p+16*8
# (The first y is at p+4.)
shl ra_load_idx, ra_instQPU, 4
shl r0, elem_num, 3
add ra_addr_in, ra_addr_in, r0

# Create VPM setup values. The vertex memory is splited into
# two ranges with 32 rows. The second area can be filled with
# data while the first will be DMA tranfered.
vpm_qsetup_h_a ra_numQPU, ra_instQPU, ra_vpm_setup0, rb_vpm_setup1
vdm_qsetup_h_a ra_numQPU, 4, ra_vdm_setup0, rb_vdm_setup1

# No stride in whole program
mov vw_setup, vdw_setup_1(0)

#############################################################
## Test Texture read

# Load x values in ra_x[1|2] and y values in rb_y[1|2].
# (This separates the tuple arguments. And 2*2 movs are redundant)
load_lin rb_stride, r:1f
:1
mov ra_x1, r0;
mov rb_y1, r1

load_lin rb_stride, r:1f
:1
mov ra_x2, r0;
mov rb_y2, r1


# Made some calucations to negate content of four registers.
mov r0, -1.0; mov r1, ra_x1
mov r2, ra_x2

fsub ra_x1, ra_x1, r1 
fsub ra_x2, ra_x2, r2 
fsub ra_x1, ra_x1, r1; fmul rb_y1, rb_y1, r0
fsub ra_x2, ra_x2, r2; fmul rb_y2, rb_y2, r0
nop

# Interleave x and y values
interleave ra_x1, rb_y1, ra_x1, rb_y1, ra_tmp0, rb_tmp0
interleave ra_x2, rb_y2, ra_x2, rb_y2, ra_tmp0, rb_tmp0

#############################################################
## Configure the VPM for writing
#
#mov vw_setup, vpm_setup(1, 1, h32(0, 0))
mov vw_setup, rb_vpm_setup1

#############################################################
## Write into the VPM.

mov rb48, ra_x1
mov rb48, rb_y1
mov rb48, ra_x2
mov rb48, rb_y2

#############################################################
## Setup the push of the VDW (virtual DMA writer).

mov vw_setup, rb_vdm_setup1
#mov vw_setup, vdw_setup_1(0) # No stride

#############################################################
## Initiate DMA write
mov rb50, rb_addr_out

# Wait for the DMA to complete
or rb39, rb50, ra39

# Trigger interrupt
exit 0
