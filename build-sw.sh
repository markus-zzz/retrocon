#!/bin/bash

# exit when any command fails
set -e

# Compiling with -O3 seem to trigger a bug (sprite bitmaps corrupted).

riscv32-unknown-elf-gcc -O2 sw/game.c -c
riscv32-unknown-elf-ld -T sw/game.ld game.o -o game.elf
riscv32-unknown-elf-objcopy -O verilog --verilog-data-width 4 --reverse-bytes=4 --only-section .ROM game.elf rom.vh
