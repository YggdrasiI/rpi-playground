## Test semaphore usage
# See head of driver.c for description.
.set LDI_LABELS, 1   # This macro requires a slight modified compiler.
.const USE_SEMA_LOCK, 1     # To test beheaviour of non-sychronized code

#############################################################
.set ra_num_inst,      ra1  # Number of instances
.set rb_inst,          rb1  # Instance id
.set ra_addr_out,      ra2  # DMA write pointer for QPU 0

                       # For semaphore lock/release on QPU 0.
                       # Both targets depends on ra_num_inst.
                       # (For QPU > 0 it jumps to :dma_end.)
.set ra_dma_acq_addr,  ra6  # Branch target for semaphore op
.set ra_dma_rel_addr,  ra4  # Branch target for 2nd sema. op

.set ra_vpm_setup,     ra5  # Setup params for VPM write
.set rb_vdw_setup,     rb5  # Setup params for DMA push

.set rb_addr_label_dist,   rb20

#############################################################
## VPM write address depends on rb_inst
.macro sema_setup_vpm, inst, out
	mov r0, vpm_setup(1, 1, h32(0, 0))
	mov r1, vpm_setup(1, 1, h32(1, 0)) - vpm_setup(1, 1, h32(0, 0))

	mul24 r2, r1, inst
#	sub   r2, r2, r1
	add out, r0, r2
.endm

.macro sema_setup_vdw, num_inst, out
	mov r0, vdw_setup_0(1, 16, dma_h32(0, 0))
	mov r1, vdw_setup_0(2, 16, dma_h32(0, 0)) - vdw_setup_0(1, 16, dma_h32(0, 0))

	mul24 r2, r1, num_inst
	sub   r2, r2, r1
	add out, r0, r2
.endm

#############################################################

## Read uniforms
mov ra_num_inst, unif
mov rb_inst, unif
mov ra_addr_out, unif

## Init setup values
sema_setup_vpm rb_inst, ra_vpm_setup
sema_setup_vdw ra_num_inst, rb_vdw_setup

#############################################################
## Evaluate Sempahore jump address
# for rb_inst > 0 just jump after the DMA write
# for rb_inst = 0 jump to the instruction where
# sempahore 0 will be aquired 'ra_num_inst' times.

# Get offset between absolute address and label address
get_address_label_offset rb_addr_label_dist

# Fill in data for default rb_inst > 0 case
load_address ra_dma_acq_addr, :dma_end, rb_addr_label_dist
load_address ra_dma_rel_addr, :dma_end, rb_addr_label_dist  # Never used

## Test
#load_address ra20, :exit, rb_addr_label_dist
#nop
#bra -, ra20

# Branch for rb_inst = 0 case
mov.setf -, rb_inst
nop

brr.anynz -, r:1f
shl r0, ra_num_inst, 3  # Each instruction is 8 byte wide.
ldi r1, :dma_aquire0
ldi r2, :dma_release0


  # Add offset to get correct absolute jump address
  add r1, r1, rb_addr_label_dist
  add r2, r2, rb_addr_label_dist
  
  # Overwrite jump targets. Add one instruction for each qpu.
  sub ra_dma_acq_addr, r1, r0
  sub ra_dma_rel_addr, r2, r0

:1
nop  # Redundant

#############################################################
## VPM Write
mov vw_setup, ra_vpm_setup
add vpm, rb_inst, elem_num

# Data is ready => Release semaphore 
.if USE_SEMA_LOCK
  mov -, srel(0)
.else
  nop
.endif

#############################################################
## DMA Write on QPU 0

# Skip write operation if rb_inst > 0
bra -, ra_dma_acq_addr
# Delay ops
nop
nop
nop
  
  # Code for QPU 0
  # Wait ra_num_inst times
  :dma_aquire12
  .rep i, 12
    .if USE_SEMA_LOCK
      mov -, sacq(0)
    .else
      nop
    .endif
  .endr
  :dma_aquire0

  # Ready for write
  mov vw_setup, rb_vdw_setup
  mov vw_setup, vdw_setup_1(0)
  nop
  mov vw_addr, ra_addr_out
  
  # Add operations, which should run parallel to DMA transfer, here.
  # [...]
  
  # Signal DMA complete.
  bra -, ra_dma_rel_addr
  nop
  read vw_wait
  nop
  
  :dma_release12
  .rep i, 12
    .if USE_SEMA_LOCK
      mov -, srel(8)
    .else
      nop
    .endif
  .endr
  :dma_release0
  
  # Target of branch
  :dma_end
  nop
  
## Continue code for all QPUs...
# Wait till QPU 0 signals that DMA transfer is finished.
# I assume this is a better approach as read vw_wait on all QPUs.
#read vw_wait
.if USE_SEMA_LOCK
  mov -, sacq(8)
.else
  nop
.endif

# Trigger a host interrupt (writing rb38) to stop the program
:exit
exit 0
