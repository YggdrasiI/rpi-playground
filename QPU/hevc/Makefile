include ../Makefile.includes
# No ARM code, but stub to compile ffmpeg hevc assembler code with vc4asm.
#
PROJECT=hevc
ASM=rpi_shader.qasm

$(PROJECT): $(PROJECT).hex 
	@echo "Done"

# Disable implict GNU make rule
%.qasm:

# Notes about sed replacements:
# - The format of the hevc shader does not satisfy the form
#   of vc4asm. The scripts try to fix that without changing
#   the source.
# - s/::/:/		=> Change unsupported label syntax '::name' 
# - s/mov interrupt… : ; nop after ALU instruction not allowed(?)
# - s/vpm_setup…     : vc4asm macro asserts positive first argument for VPMVCD_WR_SETUP,
#                      even if this bit are unused in writing case.
#                      This changes the binary...
# - s/vdw_setup_0…   : vc4asm macro asserts positive arguments. Replaced token unset bits.
#
#   Optional
# - Mov replacements  : Select explicit opcode for mov. Leads to 100% binary match of original code.
#   
$(ASM).vc4: $(ASM)
	sed -e "s/::/:/" \
		-e "s/mov interrupt, \([^;]\)\+; nop/mov interrupt, \1/" \
		-e "s/vpm_setup(\s*0,/~0xf00000 \& vpm_setup(1,/" \
		-e "s/vdw_setup_0(\s*0,\s*0,/~0x3ff0000 \& vdw_setup_0(1, 1,/" \
		-e "s/mov r0,\s*unif\s*;\s*mov r1,\s*1/or r0, unif, unif;  v8min r1, 1, 1/" \
		-e "s/asr r0,\s*r0,\s*r3\s*;\s*mov r3,\s*0/asr r0, r0, r3;  v8min r3, 0, 0/" \
		$< > $<.vc4

$(PROJECT).bin: $(ASM).vc4 $(ASM)
	$(VC4) -V -o $@ $(VC4_INCLUDES) $<

$(PROJECT).hex: $(ASM).vc4 $(ASM)
	$(VC4) -V -C $@ $(VC4_INCLUDES) $<

disasamble: $(PROJECT).hex
	vc4dis -M -v -o $(ASM).disasambled  -x $<

clean:
	rm $$(ls $(PROJECT).* $(ASM).vc4)
