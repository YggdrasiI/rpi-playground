# Rotate register example for vc4asm compiler


#############################################################
.set P, 15                # Position/Index to filter
.set R, 3                 # Rotate value to higher index
        # Appling rotation on input registers swap direction!

.set rb_first_uniform, rb3
#############################################################

# Get the first uniform
mov rb_first_uniform, unif

# Configure the VPM for writing
# See vc4asm documentation and test_vpm_write for more details.
mov vw_setup, vpm_setup(2, 1, v32(0, 0))

sub.setf r0, elem_num, P  # set zero flag on index P
mov r0, elem_num          # Mirror elem_num in accumulator because elem_num 
                          # can not be used for full roatitions.

# mov r1, 0; mov r2, 0    # Start with zero vectors
mov r1, rb_first_uniform; mov r2, rb_first_uniform
nop

# Construct first return value
# Here if-filter and rotation will be applied in one MUL operation.
# r1[P] := r0[P-R] and all other values of r1 unchanged
v8max.ifz r1 << R, r0, r0
# r1[15] = r0[12] = 12; r1[i] = r1[i], i!=15

# Construct second return value
# If the rotation is applied first, we get
# r2[P+R] := r0[P] and r2[x+R] := r2[x] for x!=P
v8max.ifz r2 , r0, r0
nop # Wait until MUL operation return result. Unfortunatly, vc4asm not warn here...
mov r2 << R, r2
# r2[2] = 15; r2[i] = r2[i-R], i!=15

# Write data into VPM
mov vpm, r1     # Rotate ('input') + Filter
mov vpm, r2     # Filter + Rotate ('output')

## move words (2 vectors) back to the host (DMA)
mov vw_setup, vdw_setup_0(2, 16, dma_v32(0, 0))
mov vw_setup, vdw_setup_1(0) # stride

## initiate the DMA (the next uniform - ra32 - is the host address to write to))
mov vw_addr, unif

# Wait for the DMA to complete
read vw_wait

# Trigger a host interrup
exit 0
