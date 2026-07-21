all: build run

build:
	nasm -f bin src/boot/boot.asm -o target/stage1.bin
	nasm -f bin src/boot/stage2/stage2.asm -o target/stage2.bin
	cat target/stage1.bin target/stage2.bin > target/boot.bin

run:
	qemu-system-x86_64 \
	-drive format=raw,file=target/boot.bin \
	-display gtk,gl=on

clean:
	rm -f target/*.bin

kill:
	pkill -f qemu-system-x86_64
