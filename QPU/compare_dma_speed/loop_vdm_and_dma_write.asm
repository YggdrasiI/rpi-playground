# Helloworld example for vc4asm compiler

#############################################################
## Horizontal VDM write setup with variable unit length
#
.macro vdw_loop_setup_b, num_units, out_0, out_1
	mov r0, vdw_setup_0(1, 16, dma_h32(0, 0))
	mov r1, vdw_setup_0(2, 16, dma_h32(0, 0)) - vdw_setup_0(1, 16, dma_h32(0, 0))

	mul24 r2, r1, num_units
	sub   r2, r2, r1
	add out_0, r0, r2

	mov r0, vdw_setup_0(1, 16, dma_h32(32, 0))
	add out_1, r0, r2
.endm                                                                                    

#############################################################
.set rb_num_elements,        rb3
.set rb_dma_num_units,       ra4
.set ra_result_base_pointer, ra5
.set rb_result_curr_pointer, rb5
.set ra_stride,						   ra6
.set ra_loop_counter,				 ra7
.set ra_vpm_setup0,          ra8
.set rb_vpm_setup1,          rb8
.set ra_dma_setup0,          ra9
.set rb_dma_setup1,          rb9
.set rb_0x0FFF,              rb10
#############################################################
# Constants
ldi rb_0x0FFF, 0x0FFF

# Load uniform data.
mov rb_num_elements, unif
mov rb_dma_num_units, unif
mov ra_result_base_pointer, unif; mov rb_result_curr_pointer, unif # same uniform

# Value of written elements per loop
shl ra_stride, rb_dma_num_units, 4

# Slight change to guarentee the abort
# of the while loop for non-multiple of 16
sub rb_num_elements, rb_num_elements, elem_num
mov ra_loop_counter, 0

# Configure the VPM for writing
mov ra_vpm_setup0, vpm_setup(1, 1, h32(0, 0))
mov rb_vpm_setup1, vpm_setup(1, 1, h32(32, 0))

# DMA setup
vdw_loop_setup_b rb_dma_num_units, ra_dma_setup0, rb_dma_setup1
mov vw_setup, vdw_setup_1(0)

# Fill some structured data (0,…,16*rb_dma_num_units)
# into VPM and swap VPM pointers.
.macro fill_vpm, start_val
	mov vw_setup, ra_vpm_setup0
	mov ra_vpm_setup0, rb_vpm_setup1; mov rb_vpm_setup1, ra_vpm_setup0
	mov r0, start_val
	mov r1, rb_dma_num_units
	:1
			mov vpm, r0
			add r0, r0, 16
			sub.setf r1, r1, 1
	brr.allnz -, r:1
		nop
		nop
		nop
.endm

## Fill the VPM for first round
fill_vpm elem_num

# Start of while loop
# The loop length is 
#     rb_num_elements / rb_dma_num_units / 16
#
dma_start:
  mov vw_setup, ra_dma_setup0
  # Swap settings
  mov ra_dma_setup0, rb_dma_setup1; mov rb_dma_setup1, ra_dma_setup0

	# Redundant(?) wait on VPM write (from fill_vpm).
  # No, this waits on dma writes...
	#mov -, vw_busy
	#read vw_wait

	# Wait of previous write would be redundant because next write
  # already blocks.
	#dma_wait
	# DMA write
	mov vw_addr, rb_result_curr_pointer
 
  # Shift output pointer. (Just required for debugging.)
  .if 1
      sub r1, rb_result_curr_pointer, ra_result_base_pointer;
      ;mul24 r0, ra_stride, 4 # stride * sizeof(int)
      add r0, r1, r0
      # restrict on 4kB 
      and r0, r0, rb_0x0FFF
      add rb_result_curr_pointer, ra_result_base_pointer, r0
  .endif

	add ra_loop_counter, ra_loop_counter, 1

  # Fill the vpm for next round
  fill_vpm elem_num

sub.setf rb_num_elements, rb_num_elements, ra_stride
brr.allnn -, r:dma_start
	nop
	nop
	nop
# End of while loop

# Write some values for debugging
.if 0
mov vw_setup, vpm_setup(1, 1, h32(0, 0))
nop
mov vpm, rb_num_elements # First element of loop abort criteria.
mov vpm, ra_loop_counter # DMA while loop counter

mov vw_setup, vdw_setup_0(2, 1, dma_h32(0, 0))
ldi r0, (30*4)

# Bug?! Writing into ra_result_base_pointer + 0
# does not write into first word 0
#mov vw_addr, ra_result_base_pointer
add vw_addr, ra_result_base_pointer, r0
.endif

# DMA store wait
dma_wait

# Exit
exit rb_num_elements
