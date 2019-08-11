#!/usr/bin/env python3

import sys
from pico8.game import game

if (len(sys.argv) != 2):
  print('Usage: {} <input.p8.png>'.format(sys.argv[0]))
  sys.exit(1)

g = game.Game.from_filename(sys.argv[1])

print('const uint32_t sprites[] = {')
for SpriteIdx in range(0, 128):
    for SpriteRow in g.gfx.get_sprite(SpriteIdx):
        print("  0x", end='')
        for SpritePixel in SpriteRow:
            print(format(SpritePixel, '1x'), end='')
        print(', /* {} */'.format(SpriteIdx))
print('};')

print('const uint8_t map[32][128] = {')
for MapCellY in range(0,32):
    print('  {', end='')
    for MapCellX in range(0,128):
        print('{}, '.format(g.map.get_cell(MapCellX, MapCellY)), end='')
    print('},')
print('};')
