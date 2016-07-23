# Helloworld example for vc4asm compiler

#############################################################
## Horizontal VDM write setup with variable unit length
#
.macro vdm_loop_setup, num_units, out_0
	mov r0, vdw_setup_0(1, 16, dma_h32(0, 0))
	mov r1, vdw_setup_0(2, 16, dma_h32(0, 0)) - vdw_setup_0(1, 16, dma_h32(0, 0))

	mul24 r2, r1, num_units
	sub   r2, r2, r1
	add out_0, r0, r2
.endm                                                                                    

#############################################################
.set rb_num_elements,        rb3
.set rb_dma_num_units,    ra4
.set ra_target_pointer,      ra5
.set ra_stride,						   ra6
.set ra_loop_counter,				 ra7
#############################################################

# Load uniform data.
mov rb_num_elements, unif
mov rb_dma_num_units, unif
mov ra_target_pointer, unif

# Value of written elements per loop
shl ra_stride, rb_dma_num_units, 4

# Slight change to guarentee the abort
# of the while loop for non-multiple of 16
sub rb_num_elements, rb_num_elements, elem_num
mov ra_loop_counter, 0

# Configure the VPM for writing
mov vw_setup, vpm_setup(1, 1, h32(0, 0))

## Fill the VPM.
mov r0, elem_num
nop
.rep i, 64
	mov vpm, r0
	add r0, r0, 16
.endr

# DMA setup
vdm_loop_setup rb_dma_num_units, vw_setup
#mov vw_setup, vdw_setup_0(4, 16, dma_h32(0, 0))
mov vw_setup, vdw_setup_1(0)

# Start of while loop
# The loop length is 
#     rb_num_elements / rb_dma_num_units / 16
#
start:

	dma_wait
	# DMA write
	mov vw_addr, ra_target_pointer

	# Commented out to made required memory constant.
	#mov r0, ra_stride
	#add ra_target_pointer, ra_target_pointer, r0
	add ra_loop_counter, ra_loop_counter, 1

sub.setf rb_num_elements, rb_num_elements, ra_stride
brr.allnn -, r:start
	nop
	nop
	nop
# End of while loop

dma_wait

# Write some values for debugging
mov vw_setup, vpm_setup(1, 1, h32(0, 0))
nop
mov vpm, rb_num_elements
mov vpm, ra_loop_counter

mov vw_setup, vdw_setup_0(2, 1, dma_h32(0, 0))
ldi r0, (30*4)
nop
nop
nop
# Bug?! Writing into ra_target_pointer + 0
# does not write into first word 0
#mov vw_addr, ra_target_pointer
add vw_addr, ra_target_pointer, r0

dma_wait

# Exit
nop
nop
nop
exit rb_num_elements
