# Ensure the build directories always exist before compiling
$(shell mkdir -p target/bin target/lst)

.PHONY: all build debug_build run debug clean kill

all: build

build:
	nasm -f bin src/boot/stage1/stage1.asm -o target/bin/stage1.bin -l target/lst/stage1.lst
	nasm -f bin src/boot/stage2/16bits/stage2.asm -o target/bin/stage2.bin -l target/lst/stage2.lst
	nasm -f bin src/kernel/kernel_0.0.asm -o target/bin/kernel.bin -l target/lst/kernel.lst
	cat target/bin/stage1.bin target/bin/stage2.bin target/bin/kernel.bin > target/boot.bin

debug_build:
	nasm -f elf32 -g -F dwarf src/boot/stage1/stage1.asm -o target/debug/stage1.o
	ld -m elf_i386 -Ttext 0x7C00 -o target/debug/stage1.elf target/debug/stage1.o
	nasm -f elf32 -g -F dwarf src/boot/stage2/16bits/stage2.asm -o target/debug/stage2.o
	ld -m elf_i386 -Ttext 0x7E00 -o target/debug/stage2.elf target/debug/stage2.o

run: build
	qemu-system-x86_64 \
		-drive format=raw,file=target/boot.bin \
		-display gtk,gl=on \
		-vga std

debug: build
	qemu-system-x86_64 \
		-drive format=raw,file=target/boot.bin \
		-S -gdb tcp::1234

clean:
	rm -rf target/

kill:
	pkill -f qemu-system-x86_64
