#############################################################
#
# Example of vw_setup usage to write 32 x and 32 y values
# (stored in four registers) into (x,y) tuples.
#
# Note: Vertical setup for vpm write, but horizontal for
#   the vdw write. The horizontal write allows us to get an
#   offset after each tuple.
#
# Note: (Unfinished, need interleaving of x,y values
# in registers which seems no basic operation.)
#############################################################
## Return address taken from first uniform
.set ra_addr_out,     ra31
mov ra_addr_out, unif

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

#ldi ra1, 0x100
#mov rb1, 2
#mov ra2, 3
#mov rb2, 4

#############################################################
## Interleave the x and y values (inplace)
interleave  ra1, rb1, ra1, rb1, ra10, rb10
interleave  ra2, rb2, ra2, rb2, ra10, rb10

#############################################################
## Configure the VPM for writing
#
# vpm_setup(num, stride, geometry)
mov vw_setup, vpm_setup(1, 1, h32(0, 0))
# Read args from right to left:
#   - Start horizontal 32 bit block at (0,0)
#   - Jump 1 block to right after writing of one block.
#     This block would be below the current block.
#   - First argument affects bits which are marked as "unused"
#     in the documentation. Meaning?!


#############################################################
## Write into the VPM.
mov rb48, ra1 # xy1 lower
mov rb48, rb1 # xy1 upper
mov rb48, ra2 # xy2 lower
mov rb48, rb2 # xy2 upper

#############################################################
## Geometry of VPM writing (xxxx^T=word):
#    (0)       (F)                                    |
#  0| 0011 … 6677 |
#( 0) 0011 … 6677 |  xy1 lower
#  2| 0011 … 6677 |
#  3| 0011 … 6677 |
#  4| 8899 … EEFF |
#( 1) 8899 … EEFF |  xy1 upper
#  6| 8899 … EEFF |
#  7| 8899 … EEFF |
#  8| 0011 … 6677 |
#( 2) 0011 … 6677 |  xy2 lower
# 10| 0011 … 6677 |
# 11| 0011 … 6677 |
# 12| 8899 … EEFF |
#( 3) 8899 … EEFF |  xy2 upper
# 14| 8899 … EEFF |
# 15| 8899 … EEFF |
#  …| …    … 
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

# 1. Configure write of xy tuples
mov vw_setup, vdw_setup_0(4, 16, dma_h32(0, 0))
# Read args from right to left:
#   - Start horizontal block at (0,0)
#   - Use all 16 words of the row as depth (this is the horizontal read length).
#   - Write 4 units/blocks. (After each unit, pointer will jump to the next line).

mov vw_setup, vdw_setup_1(0)
# Use no stride


#############################################################
## Initiate DMA write
# Write x and y values together
mov vw_addr, ra_addr_out

# Wait for the DMA to complete
or rb39, rb50, ra39

#############################################################
## End programm
exit 0
