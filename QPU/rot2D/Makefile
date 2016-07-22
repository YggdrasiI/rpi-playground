include ../Makefile.includes
PROJECT=rot2D
ASM=rot2D.asm

$(PROJECT): driver.c qpu.c $(PROJECT).bin
	g++ -g -O3 -o $(PROJECT) qpu.c driver.c $(EXTRA_SOURCES) $(EXTRA_INCLUDES) $(FLAGS)

$(PROJECT).bin: $(ASM)
	$(VC4) -V -o $@ $(VC4_INCLUDES) $<

$(PROJECT).hex: $(ASM)
	@echo "Includes: $(VC4_INCLUDES)"
	$(VC4) -V -C $@ $(VC4_INCLUDES) $<

clean:
	rm -f $(PROJECT).bin $(PROJECT).hex $(PROJECT)

run:
	sudo ./$(PROJECT) $(PROJECT).bin 0
