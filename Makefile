all: build

build:
	nasm -f bin src/boot/boot.asm -o target/stage1.bin -l target/stage1.lst
	nasm -f bin src/boot/stage2/stage2.asm -o target/stage2.bin -l target/stage2.lst
	nasm -f bin src/kernel/kernel_0.0.asm -o target/kernel.bin -l target/kernel.lst
	cat target/stage1.bin target/stage2.bin target/kernel.bin > target/boot.bin

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

kill:
	pkill -f qemu-system-x86_64
