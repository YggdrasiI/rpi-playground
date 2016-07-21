PROJECT=helloworld
MBOX_C = /opt/vc/src/hello_pi/hello_fft/mailbox.c
MBOX_INC = -I/opt/vc/src/hello_pi/hello_fft
FLAGS = -ldl
VC4_INCLUDES=../includes/vc4.qinc ../includes/my_macros.qinc 
#ASM=xy_tuple_write.example.asm
#ASM=xy_tuple_write.one_column.asm
ASM=xy_tuple_write.no_stride.asm

$(PROJECT): driver.c qpu.c $(PROJECT).bin
	g++ -g -O3 -o $(PROJECT) qpu.c driver.c $(MBOX_C) $(MBOX_INC) $(FLAGS)

$(PROJECT).bin: $(ASM)
	vc4asm -V -o $@ $(VC4_INCLUDES) $<

$(PROJECT).hex: $(ASM)
	vc4asm -V -C $@ $(VC4_INCLUDES) $<

clean:
	rm -f $(PROJECT).bin $(PROJECT).hex $(PROJECT)

run:
	sudo ./$(PROJECT) $(PROJECT).bin 0
