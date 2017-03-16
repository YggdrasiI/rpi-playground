## Test different cases of branching.
# If a branch is taken, the branch id will be stored
# (as element) to ra_taken_register.
# Finally this register will returned to arm side.

#############################################################
.set rb_first_uniform,         rb3
.set ra_taken_register,        ra2
.set ra_offset,                ra4
#############################################################
## Change register at singe position.
#  reg[index] = value
# Third operation added to fill all three branch delay slots.
.macro change_elem, reg, index, value
  sub.setf r0, elem_num, index
  mov.ifz reg, value
  nop
.endm
#############################################################

mov ra_taken_register, 0

# Get the input value (first uniform, internally loaded over rb32)
# Currently, value not used.
mov rb_first_uniform, unif

#############################################################
## Brancing

## 1. Relative branch without care of destination address.
# Could be read as 
# IF(NOT cond){
#   Lines between brr and jump target.
#   [...]
# }
# JUMP_TARGET
#
# Remember that branch instructions are executed 3 instructions delayed,
# i.e. three further instructions are always executed.
# 
change_elem ra_taken_register, 0, 1
mov.setf r0, elem_num        # 0, 1, 2, …
brr.anyz -, r:1f             # Any element zero at latest flag set (setf).
nop # Three branch
nop # delay slots.
nop # Do not use second branch here.

    # Next line only reached if branch not taken
    change_elem ra_taken_register, 0, 0

# Target of branch
:1
nop


#############################################################
## 2. Similar to example 1, but more compact 
sub.setf -, 0, elem_num  # 0, -1, -2, …
brr.anynn -, r:1f        # Any not negative
# Use macro to fill
# delay slots.
change_elem ra_taken_register, 1, 2

    # Next line only reached if branch not taken
    change_elem ra_taken_register, 1, 0

# Same label name as above. The 'f'-flag (follow) at the branch let
# the compiler selects this one.
# This is useful if a multiple used macro defines a label.
:1


#############################################################
## 3. Use destination register to store jump address for later usage.
# Take care not to trap yourself into an infinite loop...
#
.set ra_address,     ra10

# Store program counter for a label
brr ra_address,      r:loop_head

# Store number of repeats for the following while loop.
nop
nop
mov r0, 3                # Loop counter

# 'PC+4' points to the fourth instruction after the branch.
nop # ra_address store absolute position of this instruction.


:loop_head

# Dummy operations. Use second byte in ra10[2] to count the loops.
sub.setf r1, elem_num, 2    # Zero on third position
add.ifz ra_taken_register, ra_taken_register, 1
nop
nop

sub.setf r0, r0, 1
# Jump to head of loop if r0>0 (branch absolute!)
bra.allnz -, ra_address
nop
nop
nop

# Print out address
#sub.setf r1, elem_num, 15
#mov r0, ra_address
#add.ifz ra_taken_register, ra_taken_register, r0


#############################################################
## 4. If-Then-Else
# This example uses three branch instrutions. Swap
# then and else branch to reduce it on two.

shl.setf r0, elem_num, 4
#mov.setf r0, -1

brr.allnn -, r:then
nop
nop # Two nop's seems enough.
brr.anyn -, r:else 
nop
nop

:then
change_elem ra_taken_register, 3, 4
nop         # Omits overlapping warning of .back

# Shift branch up to use delay slots.
.back 3
brr -, r:end
.endb

:else
change_elem ra_taken_register, 3, -4
:end


#############################################################
## 5. Method call with jump back address
# First branch stores absolute address of PC+4 in ra_address
# and jump to :method.
# At the end of :method, we jump back and continue with step 6.
# (third jump.)

brr ra_address, :method5
nop
nop
nop

:back_target5
brr -, :step6
nop
nop
nop

:method5
change_elem ra_taken_register, 4, 5
bra -, ra_address          # return
nop
nop
nop

# Not reached if above code works...
change_elem ra_taken_register, 4, -5


:step6
#############################################################
## 6. Modification of 5. with only two brachings.
# First branch stores absolute address of PC+4 in ra_address
# and jump to :method.
# At the end of :method, we jump back, but modify ra_address
# by an offset of two labels.
#
# Requires modified vc4asm with 'mov :label' support.

brr ra_address, :method6
mov r0, (:step7-:back_target6)  # Evaluated at compile time
nop
nop

:back_target6
# Not required...
# brr -, :step6
# nop
# nop
# nop

:method6
add ra_address, ra_address, r0   # Change target to step7
change_elem ra_taken_register, 5, 6
bra -, ra_address          # return
nop
nop
nop

# Not reached if above code works...
change_elem ra_taken_register, 5, -6


:step7
#############################################################
## 7. ...
# Repeat single command and decide, i.e. by the number 
# of used QPU instances, how often the command should run.
#
# Approach can be used for loop unrolling.
.set step7_N, 5
mov ra20, -(step7_N*8)           # Each command is 8 byte width.
nop
brr -, :step7_add0, ra20   # add -5*8 to label
mov r1, 2
nop
nop

.rep i, 12
    add r1, r1, 1
.endr
:step7_add0

# r1 is 2 + step7_N*1
change_elem ra_taken_register, 6, r1


:step8
#############################################################
## 8. Show difference between absolute and relative addresses
#
# The macro get_address_label_offset evaluates the distance
# between both braching variants.
#

# Enable 
.set LDI_LABELS, 1

# Get offset (constant value during run, but depends on memory layout)
get_address_label_offset ra_offset
nop # Wait till ra_offset is available

bra -, :step8_set_value, ra_offset
# or
#brr-, :step8_set_value
# jump to same position
nop
nop
nop

:step8_set_value
    change_elem ra_taken_register, 7, 8
    # No to next section
    brr -, :step9
    nop
    nop
    nop

# Not reached
change_elem ra_taken_register, 7, -8


:step9
#############################################################
## 9. ...


#############################################################
## Push debug variables and quit

# Configure the VPM for writing
# See vc4asm documentation and test_vpm_write for more details.
mov vw_setup, vpm_setup(1, 16, v32(0, 0))

# Write into the VPM.
mov vpm, ra_taken_register

## move 16 words (1 vector) back to the host (DMA)
mov vw_setup, vdw_setup_0(1, 16, dma_v32(0, 0))
mov vw_setup, vdw_setup_1(0) # stride

## initiate the DMA (the next uniform - ra32 - is the host address to write to))
mov vw_addr, unif

# Wait for the DMA to complete
read vw_wait

# Trigger a host interrupt (writing rb38) to stop the program
exit 0
