# RetroCon - The Game Console

## Quick start guide

Begin by borrowing graphics assets from the Celeste game by following the
instructions in tools/README.

### Build the firmware
```
./build-sw.sh
```

### Build the Verilator based simulator
```
cd sim/verilator
ln -s ../../rom.vh .
# My Verilator install is a bit messed up so the following script will need
# some hand editing before it works outside my environment.
./build-all.sh
./vgamon --frame-rate=0
```

### Generate bitstream for ULX3S using SymbiFlow tools
```
cd syn/SymbiFlow
ln -s ../../rom.vh .
./build-ulx3s.sh
```
