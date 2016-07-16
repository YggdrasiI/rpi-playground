PROJECT=helloworld
MBOX_C = /opt/vc/src/hello_pi/hello_fft/mailbox.c
MBOX_INC = -I/opt/vc/src/hello_pi/hello_fft
FLAGS = -ldl

$(PROJECT): driver.c qpu.c $(PROJECT).bin
	g++ -g -O3 -o $(PROJECT) qpu.c driver.c $(MBOX_C) $(MBOX_INC) $(FLAGS)

$(PROJECT).bin: $(PROJECT).asm
	vc4asm -V -o $@ ../includes/vc4.qinc $<

$(PROJECT).hex: $(PROJECT).asm
	vc4asm -V -C $@ ../includes/vc4.qinc $<

clean:
	rm -f rot2D.bin

run:
	sudo ./$(PROJECT) $(PROJECT).bin 100
