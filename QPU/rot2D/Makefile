MBOX_C = /opt/vc/src/hello_pi/hello_fft/mailbox.c
MBOX_INC = -I/opt/vc/src/hello_pi/hello_fft
FLAGS = -ldl

rot2D: driver.c qpu.c rot2D.bin
	g++ -g -O3 -o rot2D qpu.c driver.c $(MBOX_C) $(MBOX_INC) $(FLAGS)


rot2D.bin: rot2D.asm
	../assembler/qpu-assembler -o rot2D.bin < rot2D.asm 
	#vc4asm -o rot2D.bin < rot2D.asm 

clean:
	rm -f rot2D.bin

run:
	sudo ./rot2D rot2D.bin 100
