
SRC=procsim.d machine.d microblaze.d pisa.d sparc.d avr32.d alpha.d mips.d arm7tdmi.d arm926ejs.d powerpc.d sh4.d nios2.d xtensa.d

procsim: $(SRC)
#	dmd -ofprocsim $(SRC) -g -inline -release -O
	dmd -ofprocsim $(SRC) -g -debug

microblaze: procsim
	./procsim -m microblaze -l transcript \
		--initcheck \
		-P imem:0x00000000::microblaze_imem.bin \
		-P dmem:0x10000000:0x10000:microblaze_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::8000
	cat stdout.bin

mips1: procsim
	./makegdb <gdbin.txt >gdbin.bin
	./procsim -m mips1 -l transcript \
		--initcheck \
		-P mem:0x00000000::mips1_imem.bin \
		-P mem:0x10000000:0x10000:mips1_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::8000
	cat stdout.bin

mipsel1: procsim
	./procsim -m mipsel1 -l transcript \
		--initcheck \
		-P imem:0x00000000::mipsel1_imem.bin \
		-P dmem:0x10000000:0x10000:mipsel1_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000
	cat stdout.bin

sparcv7: procsim
	./procsim -m sparcv7 -l transcript \
		--initcheck \
		-P imem:0x00000000::sparcv7_imem.bin \
		-P dmem:0x10000000:0x10000:sparcv7_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000
	cat stdout.bin

sparcv7w: procsim
	./procsim -m sparcv7w -l transcript \
		--initcheck \
		-P imem:0x00000000::sparcv7w_imem.bin \
		-P dmem:0x10000000:0x10000:sparcv7w_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000
	cat stdout.bin

pisa: procsim
	./procsim -m pisa -l transcript \
		--initcheck \
		-P imem:0x00000000::pisa_imem.bin \
		-P dmem:0x10000000:0x10000:pisa_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000
	cat stdout.bin

arm926ejs: procsim
	./procsim -m arm926ejs -l transcript \
		--initcheck \
		-P imem:0x00000000::arm926ejs_imem.bin \
		-P dmem:0x10000000:0x10000:arm926ejs_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000
	cat stdout.bin

arm7tdmi: procsim
	./procsim -m arm7tdmi -l transcript \
		--initcheck \
		-P imem:0x00000000::arm7tdmi_imem.bin \
		-P dmem:0x10000000:0x10000:arm7tdmi_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000
	cat stdout.bin

powerpc: procsim
	./procsim -m powerpc -l transcript \
		-P mem:0x00000000::powerpc_imem.bin \
		-P mem:0x00040000:0x40000:powerpc_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000 \
		-s powerpc.sym
	cat stdout.bin

sh4: procsim
	./procsim -m sh4 -l transcript \
		--initcheck \
		-P mem:0x00000000:0x10000:sh4_imem.bin \
		-P mem:0x00010000:0x20000:sh4_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000 \
		-s sh4.sym
	cat stdout.bin

nios2: procsim
	./procsim -m nios2 -l transcript \
		-P imem:0x00000000::nios2_imem.bin \
		-P dmem:0x10000000:0x10000:nios2_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000 \
		-s nios2.sym
	cat stdout.bin

xtensa: procsim
	./procsim -m xtensa -l transcript \
		--initcheck \
		-P mem:0x00000000::xtensa_imem.bin \
		-P dmem:0x10000000:0x10000:xtensa_dmem.bin \
		-P uartfile:0x10010000::stdin.bin:stdout.bin \
		-P uartsocket:0x10011000::9000 \
		-s xtensa.sym
	cat stdout.bin

clean: procsim
	rm procsim *.o
