include ../Makefile.includes
# No ARM code, but stub to compile ffmpeg hevc assembler code with vc4asm.
#
PROJECT=hevc
SHADER=rpi_shader
ASM=$(SHADER).qasm
#VC4=$(HOME)/software/git/vc4asm/bin/vc4asm
SHELL=/bin/bash -o pipefail

$(PROJECT): with_header
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
#                      Combination with '0xMASK & ' preserve final binary result.
# - s/vdw_setup_0…   : vc4asm macro asserts positive arguments. Replaced token unset bits.
#
#   Optional
# - Mov replacements  : Select explicit opcode for mov. Leads to 100% binary match of original code.
#   
$(ASM).vc4: $(ASM)
	sed \
		-e "s/mov interrupt, \([^;]\)\+; nop/mov interrupt, \1/" \
		-e "s/vpm_setup(\s*0,/~0xf00000 \& vpm_setup(1,/" \
		-e "s/vdw_setup_0(\s*0,\s*0,/~0x3ff0000 \& vdw_setup_0(1, 1,/" \
		-e "s/mov r0,\s*unif\s*;\s*mov r1,\s*1/or r0, unif, unif;  v8min r1, 1, 1/" \
		-e "s/asr r0,\s*r0,\s*r3\s*;\s*mov r3,\s*0/asr r0, r0, r3;  v8min r3, 0, 0/" \
		$< > $<.vc4
		#-e "s/::/:/" \

# Variant for https://github.com/YggdrasiI/vc4asm fork. Could generate
# header file, rpi_shader.h, too.
# First, assemble hex values and then fill them into an template file.
# Moreover, a header with the ::name labels will be created.
#
with_header: $(PROJECT).c
$(PROJECT).c: $(ASM).vc4 $(ASM)
	$(VC4) -C $(SHADER).hex -H $(SHADER:=.h) -V -v $(VC4_INCLUDES) $<
	$(SHADER)=$$(cat "$(SHADER).hex") envsubst < sources/$(SHADER).c.template > $(PROJECT).c


# Variant for unmodified vc4asm
without_header: $(PROJECT).hex
$(PROJECT).hex: $(ASM).vc4 $(ASM)
	$(VC4) -V -C $@ $(VC4_INCLUDES) $<

$(PROJECT).bin: $(ASM).vc4 $(ASM)
	$(VC4) -V -o $@ $(VC4_INCLUDES) $<

disasamble: $(PROJECT).hex
	vc4dis -M -v -o $(ASM).disasambled  -x $<

# Show differences to original code, but ignore comments after instructions
# Note: The differences by different label ordering can be ignored.
diff: hevc.c sources/rpi_shader.c
	diff $(SHADER:=.h) sources/rpi_shader.h
	diff <(cut -d' ' -f1,2,3,4,5 hevc.c) <( cut -d' ' -f1,2,3,4,5 sources/rpi_shader.c)

clean:
	rm $$(ls $(SHADER:=.h) $(PROJECT).* $(ASM).vc4)
