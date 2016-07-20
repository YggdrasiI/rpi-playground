#############################################################
#
# Example of vw_setup usage to write 32 x and 32 y values
# (stored in four registers) into (x,y) tuples.
#
# Note: Vertical setup for VPM write, but horizontal for
# VDW write. The horizontal write allows us to get an
# offset after each value, but not each block (16 values)
#
#############################################################
## Return address taken from first uniform
.set ra_addr_out,     ra31
mov ra_addr_out, unif

#############################################################
## Extended setup with blockmode argument. (no effect?!)
.func my_vdw_setup_1(stride, blockmode)
    .assert !(stride & ~0xffff) # VPM supports 16 bit stride rather than 13 as documented
    .assert !(blockmode & ~0x1)
    0xc0000000 | stride | blockmode << 16
.endf
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
#   - Jump 16. blocks to right after writing of one block.
#     This block would be below the current block!
#   - First argument affects bits which are marked as "unused"
#     in the documentation. Meaning?!


#############################################################
## Write into the VPM.
mov rb48, ra1 # x1
mov rb48, ra2 # x2
mov rb48, rb1 # y1
mov rb48, rb2 # y2

#############################################################
## Geometry of VPM writing (xxxx=word):
#
#     ( 0) ( 1) … (15)
#  0| 0000 **** … ****
#( 0) 1111 **** … ****
#  …| …           …
# 15| FFFF **** … ****
#  …| …    …      …
# 48| 0000 ****
#( 4) 1111 **** … ****
#  …| …           …
# 63| FFFF **** … ****
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
mov vw_setup, vdw_setup_0(2*16, 1, dma_h32(0, 0))
# Read args from right to left:
#   - Start horizontal block at (0,0)
#   - Use 1 block (=4 bytes) as depth (this is the horizontal read length)
#   - Write 32 units. (After each unit, pointer will jump to the next line)

mov vw_setup, my_vdw_setup_1(4, 1)
# Skip 4 bytes after each unit. It leads to the
# following write structure: x,_,x,_,…

#############################################################
## Initiate DMA writes
# x values
mov vw_addr, ra_addr_out

# y values.
mov vw_setup, vdw_setup_0(2*16, 1, dma_h32(32, 0))
add vw_addr, ra_addr_out, 4


#############################################################
## End programm
exit 0
