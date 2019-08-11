#include <stdint.h>

#include "cartridge.h"

#define MEM_BASE_ROM 0x00000000UL
#define MEM_BASE_RAM 0x10000000UL
#define MEM_BASE_VRAM 0x20000000UL
#define MEM_BASE_SYSCON 0x30000000UL

#define VRAM_BASE_BITMAPS 0UL
#define VRAM_BASE_SPRITES 4096UL
#define VRAM_BASE_TILES (VRAM_BASE_SPRITES + 64*4)

#define XRES 320
#define YRES 240

#define SPRITE(hpos, vpos, idx)                                                \
  (1 << 31) | ((idx) << 17) | ((hpos) << 8) | (vpos)

struct {
  int x, y;
  int vx, vy;
  int idx;
} objects[8];

static void load_level(int mx, int my, int sx, int sy) {
    mx *= 16;
    my *= 16;
    sx /= 4;
    volatile uint32_t *p = (uint32_t *)(MEM_BASE_VRAM + VRAM_BASE_TILES);
    for (int j = 0; j < 16; j++) {
      for (int i = 0; i < 16 / 4; i++) {
        p[(j+sy)*64/4+i + sx] = (map[mx+j][my+i*4] << 0)  |
                              (map[mx+j][my+i*4+1] << 8)  |
                              (map[mx+j][my+i*4+2] << 16) |
                              (map[mx+j][my+i*4+3] << 24);
      }
    }
}
#if 1
void _start(void) {
  // Upload sprites to VRAM.
  volatile uint32_t *p = (uint32_t *)(MEM_BASE_VRAM + VRAM_BASE_BITMAPS);
  for (int i = 0; i < sizeof(sprites) / sizeof(sprites[0]); i++) {
    *p++ = sprites[i];
  }

  // Initialize objects.
  for (int i = 0; i < 8; i++) {
    objects[i].x = 10 * i + 20;
    objects[i].y = 20 * i + 20;
    objects[i].idx = 1 + 10 * i;
    objects[i].vx = (i & 1) ? 1 : -1;
    objects[i].vy = (i & 2) ? 1 : -1;
  }

  load_level(0, 0, 4, 4);

  volatile uint32_t *vga_vactive = (uint32_t *)MEM_BASE_SYSCON;
  while (1) {
    // Wait for vblank to end
    while (!(*vga_vactive));
    // Wait for vblank
    while (*vga_vactive);

    // Upload sprite positions to VRAM.
    volatile uint32_t *q = (uint32_t *)(MEM_BASE_VRAM + VRAM_BASE_SPRITES);
    for (int i = 0; i < 8; i++) {
      q[i] = SPRITE(objects[i].x, YRES - objects[i].y, objects[i].idx);
    }
    // Update sprite positions.
    for (int i = 0; i < 8; i++) {
      objects[i].x += objects[i].vx;
      objects[i].y += objects[i].vy;
      if (objects[i].x < 0 || objects[i].x > XRES) objects[i].vx *= -1;
      if (objects[i].y < 0 || objects[i].y > YRES) objects[i].vy *= -1;
    }
  }
}
#else
void _start(void) {
  // Upload solid color sprites to VRAM.
  volatile uint32_t *p = (uint32_t *)(MEM_BASE_VRAM + VRAM_BASE_BITMAPS);
  for (unsigned int i = 0; i < 128; i++) {
    *p++ = 0x11111111UL * (i & 0xf);
  }

  {
    // Disable all sprites.
    volatile uint32_t *q = (uint32_t *)(MEM_BASE_VRAM + VRAM_BASE_SPRITES);
    for (int i = 0; i < 64; i++) {
      q[i] = 0;
    }
  }

  {
    // Clear all tiles.
    volatile uint32_t *p = (uint32_t *)(MEM_BASE_VRAM + VRAM_BASE_TILES);
    for (int i = 0; i < 64 * 32 / 4; i++) {
      *p++ = i & 1;
    }
  }

  while (1);
}
#endif
