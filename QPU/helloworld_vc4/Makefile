include ../Makefile.includes
PROJECT=helloworld
ASM=$(PROJECT).asm

$(PROJECT): driver.c qpu.c $(PROJECT).bin
	g++ -g -O3 -o $(PROJECT) qpu.c driver.c $(EXTRA_SOURCES) $(EXTRA_INCLUDES) $(FLAGS)

$(PROJECT).bin: $(ASM)
	$(VC4) -V -o $@ $(VC4_INCLUDES) $<

$(PROJECT).hex: $(ASM)
	$(VC4) -V -C $@ $(VC4_INCLUDES) $<

clean:
	rm -f $(PROJECT).bin $(PROJECT).hex $(PROJECT)

run:
	sudo ./$(PROJECT) $(PROJECT).bin 100
