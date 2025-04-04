all: assemble floppy qemu

assemble:
	nasm -fbin boot.asm -o boot.bin
	nasm -fbin pong.asm -o pong.bin

floppy: assemble
	dd if=/dev/zero  of=floppy.img bs=512 count=2880
	dd if=boot.bin of=floppy.img conv=notrunc
	dd if=pong.bin of=floppy.img seek=1 conv=notrunc

qemu: floppy
	qemu-system-i386 -fda floppy.img -m 1M -smp 1 -vga std -monitor stdio