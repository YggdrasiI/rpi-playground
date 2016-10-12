#############################################################
#
# Example of vw_setup usage to write 32 x and 32 y values
# (stored in four registers) into (x,y) tuples.
#
# Note: Vertical setup for vpm write, but horizontal for
#   the vdw write. The horizontal write allows us to get an
#   offset after each tuple.
#
# Note: This aproach (Vertical vpm setup) is good to set
#   an arbitary stride after each (x,y) tuple, but you can only
#   write out the four blocks (64 words) of one column.
#   It is not possible to push multiple columns (i.e. provided from 
#   different QPUs) in one DMA write command.
#   Lock into xy_tuple_write.no_stride.asm for an approach 
#   which pushes more DMA data in one call.
#
#############################################################
## Return address taken from first uniform
.set ra_addr_out,     ra31
mov ra_addr_out, unif

#############################################################

#############################################################
## Example content to write
mov ra1, elem_num
add ra2, elem_num, 16
mov r0, elem_num
nop ;
nop ; mov rb1, r0 << 1
nop ; mov rb2, r0 << 8

# Add constant to test higher order bytes
mov rb10, 100000
nop
add ra1, ra1, rb10 
add ra2, ra2, rb10 

#############################################################
## Configure the VPM for writing
#
# vpm_setup(num, stride, geometry)
mov vw_setup, vpm_setup(1, 16, v32(0, 0))
# Read args from right to left:
#   - Start vertical block at (0,0) and use 4 bytes width
#   - Jump 16 blocks to right after writing of one block.
#     This block would be below the current block.
#   - First argument affects bits which are marked as "unused"
#     in the documentation. Meaning?!


#############################################################
## Write into the VPM.
mov vpm, ra1 # x1
mov vpm, ra2 # x2

# Jump to second column
mov vw_setup, vpm_setup(1, 16, v32(0, 1))
mov vpm, rb1 # y1
mov vpm, rb2 # y2

#############################################################
## Geometry of VPM writing (xxxx=word):
#       x    y
#     ( 0) ( 1) ( 2) … (15)
#  0| 0000 0000 **** … ****
#( 0) 1111 1111 **** … ****
#  …| …    …         …
# 15| FFFF FFFF **** … ****
# 16| 0000 0000 ****
#( 2) 1111 1111 **** … ****
#  …| …    …         …
# 31| FFFF FFFF **** … ****
# 32| **** **** …
#
#(Block)

#############################################################
## Setup the push of the VDW (virtual DMA writer).
#
# Complete setup need two writes into vw_setup register.
# vc4asm contain the helper functions
# vdw_setup_0(units, depth, dma_geometry) and
# vdw_setup_1(stride) for this operation.
#
# Writing of y require second setup call, see below.

# 1. Configure write of x values
mov vw_setup, vdw_setup_0(2*16, 2, dma_h32(0, 0))
# Read args from right to left:
#   - Start horizontal block at (0,0)
#   - Use 2 words as depth (this is the horizontal read length).
#   - Write 32 units. (After each unit, pointer will jump to the next line).

mov vw_setup, vdw_setup_1(0)
# No skip This leads to the 
# following write structure: x,y,x,y,…

#############################################################
## Initiate DMA write
# Write x and y values together
mov vw_addr, ra_addr_out

# Wait for the DMA to complete
or rb39, vw_wait, ra39

#############################################################
## End programm
exit 0
