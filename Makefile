all: build

build:
	nasm -f bin src/boot/stage1/stage1.asm -o target/bin/stage1.bin -l target/lst/stage1.lst
	nasm -f bin src/boot/stage2/16bits/stage2.asm -o target/bin/stage2.bin -l target/lst/stage2.lst
	nasm -f bin src/kernel/kernel_0.0.asm -o target/bin/kernel.bin -l target/lst/kernel.lst
	cat target/bin/stage1.bin target/bin/stage2.bin target/bin/kernel.bin > target/boot.bin

run: build
	qemu-system-x86_64 \
		-drive format=raw,file=target/boot.bin \
		-display gtk,gl=on

debug: build
	qemu-system-x86_64 \
		-drive format=raw,file=target/boot.bin \
		-S \
		-s

clean:
	rm -f target/*.bin target/*.lst
	rm -f target/bin/*.bin
	rm -f target/lst/*.lst
kill:
	pkill -f qemu-system-x86_64
