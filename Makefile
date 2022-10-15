NAME=Wordle

all: Wordle

Wordle: Wordle.asm
	nasm -f elf -F dwarf -g Wordle.asm
	gcc -g -m32 -o Wordle Wordle.o
	rm -rf Wordle.o
