# Helloworld example for vc4asm compiler

#############################################################
.macro exit, flag
	mov interrupt, flag
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
ldi rb49, 0xa00

# Write sum of uniform and constant into the VPM.
add rb48, ra1, rb_first_uniform

## move 16 words (1 vector) back to the host (DMA)
ldi rb49, 0x88010000

## initiate the DMA (the next uniform - ra32 - is the host address to write to))
or rb50, ra32, 0

# Wait for the DMA to complete
or rb39, rb50, ra39

# Trigger a host interrupt (writing rb38) to stop the program
exit rb_first_uniform
