all:
	ruby bit_enc.rb raw_payload.bin > raw_payload_enc.asm
	nasm -f bin decode.asm -o decode.o 
	ruby enc.rb decode.o > ecalc.asm
	nasm -f bin ecalc.asm -o ecalc.o 
	cat ecalc.o | ruby -e 'v=""; $$stdin.gets.each_byte{|b| v << "0x%x, " % b }; puts "unsigned char buf[] = { " + v + " };";' > payload.h 

clean:
	rm -f *.o *.exe *.obj *.pdb

