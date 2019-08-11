#!/bin/bash

set -e

rm -rf obj_dir

VERILATOR_ROOT=/home/markus/work/install/
verilator -trace -cc ../../rtl/*.v ../../rtl/support/*.v +1364-2005ext+v --top-module game_top -Wno-fatal
VERILATOR_ROOT=/home/markus/work/install/share/verilator/
cd obj_dir; make -f Vgame_top.mk VERILATOR_ROOT=$VERILATOR_ROOT; cd ..
g++ vgamon.cpp obj_dir/Vgame_top__ALL.a -I obj_dir/ -I $VERILATOR_ROOT/include/ $VERILATOR_ROOT/include/verilated.cpp $VERILATOR_ROOT/include/verilated_vcd_c.cpp -o vgamon `pkg-config --cflags --libs gtk+-3.0`
