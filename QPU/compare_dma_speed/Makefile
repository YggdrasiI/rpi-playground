include ../Makefile.includes
PROJECT=dma_speed
ASM1 = loop_dma_write.asm
ASM2 = loop_vdm_and_dma_write.asm
ASM = $(ASM1) $(ASM2)

$(PROJECT): driver.c qpu.c $(ASM:asm=bin)
	g++ -g -O3 -o $(PROJECT) qpu.c driver.c $(EXTRA_SOURCES) $(EXTRA_INCLUDES) $(FLAGS)

%.bin: %.asm $(VC4_INCLUDES)
	$(VC4) -V -o $@ $(VC4_INCLUDES) $<

%.hex: %.asm $(VC4_INCLUDES)
	@#$(VC4) -V -C $@ $(VC4_INCLUDES) $<
	$(VC4) -V -C $@ $(VC4_INCLUDES) $<

clean:
	rm -f $(ASM:asm=hex)
	rm -f $(ASM:asm=bin) $(PROJECT)

run:
	@echo "DMA write loop:"
	sudo ./$(PROJECT) $(ASM1:asm=bin)
	@echo "\nVPM+DMA write loop:"
	sudo ./$(PROJECT) $(ASM2:asm=bin)
