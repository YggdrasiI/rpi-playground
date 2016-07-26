# Helloworld example for vc4asm compiler

#############################################################
.macro exit, flag
	#mov interrupt, flag # problematic?!
	or interrupt, ra39, flag 
	nop; nop; thrend
	nop 
	nop 
.endm

#############################################################
.set rb_first_uniform,         rb3
#############################################################

# Get the input value (first uniform, internally loaded over rb32)
mov rb_first_uniform, unif

# Load the value we want to add to the input into a register
ldi ra1, 0x1234

# Configure the VPM for writing
# See vc4asm documentation and test_vpm_write for more details.
mov vw_setup, vpm_setup(1, 16, v32(0, 0))

# Write sum of uniform and constant into the VPM.
add vpm, ra1, rb_first_uniform

## move 16 words (1 vector) back to the host (DMA)
mov vw_setup, vdw_setup_0(1, 16, dma_v32(0, 0))
mov vw_setup, vdw_setup_1(0) # stride

## initiate the DMA (the next uniform - ra32 - is the host address to write to))
mov vw_addr, unif

# Wait for the DMA to complete
read vw_wait

# Trigger a host interrupt (writing rb38) to stop the program
exit rb_first_uniform
