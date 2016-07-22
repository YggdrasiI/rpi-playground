# Rotation of (x,y)-vectors by fixed angle (for vc4asm compiler)

#############################################################
.set ra_addr_x,         ra3
.set rb_addr_y,         rb3
.set ra_load_idx,       ra5
.set Stride,            0x10

#############################################################
## Pushes two texture request commands.
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
.set ra_numQPU,         ra29
.set rb_N,              rb29
.set ra_sin,            ra28
.set rb_cos,            rb28
.set ra_addr_in,        ra27
.set rb_addr_out,       rb27
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

# Start at element 0 and set read addresses to p, p+8, …, p+16*8
# This read x values with stride of 4 bytes (=y).
mov ra_load_idx, 0
mul24 r0, elem_num, 8
add ra_addr_in, ra_addr_in, r0
nop

#############################################################
## Test Texture read

# Load x values in ra1 and y values in rb1.
# (This separates the tuple arguments.)
#load_lin Stride, r:1f
#:1
#mov ra1, r0; mov rb1, r1

read_lin Stride
nop;        ldtmu0
mov r0, r4; ldtmu0                                                                    
mov r1, r4                                                                            
mov ra1, r0; mov rb1, r1

# Made some calucations
nop
fsub ra1, ra1, r0 
mov r2, -1.0
fsub ra1, ra1, r0; fmul rb1, rb1, r2
nop;

# Interleave x and y values
interleave ra1, rb1, ra1, rb1, ra10, rb10

#############################################################
## Configure the VPM for writing
#
mov vw_setup, vpm_setup(1, 1, h32(0, 0))

#############################################################
## Write into the VPM.

mov rb48, ra1
mov rb48, rb1
#mov rb48, elem_num
#mov rb48, elem_num
#mov rb48, ra1
#mov rb48, r1 << 2

#############################################################
## Setup the push of the VDW (virtual DMA writer).

mov vw_setup, vdw_setup_0(2, 16, dma_h32(0, 0)) # num_units, width, geometry
mov vw_setup, vdw_setup_1(0) # No stride

#############################################################
## Initiate DMA write
mov rb50, rb_addr_out

# Wait for the DMA to complete
or rb39, rb50, ra39

# Trigger interrupt
exit 0
