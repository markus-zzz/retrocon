#!/bin/bash

set -e -x
yosys game.ys
nextpnr-ecp5 \
	--json game.json \
	--textcfg game.config \
	--lpf ulx3s.lpf \
	--25k

ecppack --idcode 0x21111043 game.config game.bit
