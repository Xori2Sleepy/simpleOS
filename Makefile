# Simple Makefile
all: build run

build:
	nasm -f bin src/boot/boot.asm -o target/boot.bin

run:
	qemu-system-x86_64 -drive format=raw,file=target/boot.bin

clean:
	rm -f target/*.bin
