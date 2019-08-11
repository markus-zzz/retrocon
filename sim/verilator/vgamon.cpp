/*
 * Copyright (C) 2019 Markus Lavin (https://www.zzzconsulting.se/)
 *
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

#include "Vgame_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <assert.h>
#include <cairo.h>
#include <gdk/gdkkeysyms.h>
#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define XRES 640
#define YRES 480

GdkPixbuf *vga_pixbuf;
static int vga_frame_idx = -1;
static unsigned buttons = 0;

static struct {
  int scale;
  int frame_rate;
  int save_frame_from;
  int save_frame_to;
  const char *save_frame_prefix;
  int exit_after_frame;
  int trace;
} options;

static Vgame_top *tb = NULL;
static VerilatedVcdC *trace = NULL;
static unsigned tick = 0;

static void put_pixel(GdkPixbuf *pixbuf, int x, int y, guchar red, guchar green,
                      guchar blue) {
  int width, height, rowstride, n_channels;
  guchar *pixels, *p;

  n_channels = gdk_pixbuf_get_n_channels(pixbuf);

  g_assert(gdk_pixbuf_get_colorspace(pixbuf) == GDK_COLORSPACE_RGB);
  g_assert(gdk_pixbuf_get_bits_per_sample(pixbuf) == 8);
  g_assert(!gdk_pixbuf_get_has_alpha(pixbuf));
  g_assert(n_channels == 3);

  width = gdk_pixbuf_get_width(pixbuf);
  height = gdk_pixbuf_get_height(pixbuf);

  g_assert(x >= 0 && x < width);
  g_assert(y >= 0 && y < height);

  rowstride = gdk_pixbuf_get_rowstride(pixbuf);
  pixels = gdk_pixbuf_get_pixels(pixbuf);

  p = pixels + y * rowstride + x * n_channels;
  p[0] = red;
  p[1] = green;
  p[2] = blue;
}

static gboolean on_draw_event(GtkWidget *widget, cairo_t *cr,
                              gpointer user_data) {
  (void)widget;
  (void)user_data;
  cairo_scale(cr, options.scale, options.scale);
  gdk_cairo_set_source_pixbuf(cr, vga_pixbuf, 0.0, 0.0);
  cairo_paint(cr);
  cairo_fill(cr);

  /* Draw some text */
  cairo_identity_matrix(cr);
  cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL,
                         CAIRO_FONT_WEIGHT_NORMAL);
  cairo_set_font_size(cr, 14);
  cairo_set_source_rgb(cr, 255, 255, 255);
  cairo_move_to(cr, 10, 15);
  char buf[32];
  snprintf(buf, sizeof(buf), "Frame #%03d", vga_frame_idx);
  cairo_show_text(cr, buf);

  return FALSE;
}

static gboolean on_key_press(GtkWidget *widget, GdkEventKey *event,
                             gpointer user_data) {
  (void)widget;
  (void)user_data;
  switch (event->keyval) {
  case GDK_KEY_Left:
    buttons |= (1 << 0);
    break;
  case GDK_KEY_Right:
    buttons |= (1 << 1);
    break;
  case GDK_KEY_Up:
    buttons |= (1 << 2);
    break;
  case GDK_KEY_Down:
    buttons |= (1 << 3);
    break;
  case GDK_KEY_x:
    buttons |= (1 << 4);
    break;
  case GDK_KEY_z:
    buttons |= (1 << 5);
    break;
  default:
    break;
  }

  return FALSE;
}

static gboolean on_key_release(GtkWidget *widget, GdkEventKey *event,
                               gpointer user_data) {
  (void)widget;
  (void)user_data;
  switch (event->keyval) {
  case GDK_KEY_Left:
    buttons &= ~(1 << 0);
    break;
  case GDK_KEY_Right:
    buttons &= ~(1 << 1);
    break;
  case GDK_KEY_Up:
    buttons &= ~(1 << 2);
    break;
  case GDK_KEY_Down:
    buttons &= ~(1 << 3);
    break;
  case GDK_KEY_x:
    buttons &= ~(1 << 4);
    break;
  case GDK_KEY_z:
    buttons &= ~(1 << 5);
    break;
  default:
    break;
  }

  return FALSE;
}

int clk_cb() {
  static enum {
    h_wait_for_hsync_0,
    h_wait_for_hsync_1,
    h_skip_back_porch,
    h_active_pixels
  } h_state = h_wait_for_hsync_0;

  static enum {
    v_wait_for_vsync_0,
    v_wait_for_vsync_1,
    v_skip_back_porch,
    v_active_pixels
  } v_state = v_active_pixels;

  static int hcntr = 0;
  static int vcntr = 0;

  int frame_done = 0;

  if (h_state == h_active_pixels && v_state == v_active_pixels) {
    assert(hcntr < XRES);
    assert(vcntr < YRES);
    put_pixel(vga_pixbuf, hcntr, vcntr, tb->vga_red_o, tb->vga_green_o,
              tb->vga_blue_o);
  }

  switch (h_state) {
  case h_wait_for_hsync_0:
    if (tb->vga_hsync_o == 0)
      h_state = h_wait_for_hsync_1;
    break;
  case h_wait_for_hsync_1:
    if (tb->vga_hsync_o == 1) {
      h_state = h_skip_back_porch;
      hcntr = 0;

      /* This happens once per scanline so this is where we run the vertical
       * state machine */
      switch (v_state) {
      case v_active_pixels:
        if (++vcntr == YRES) {
          vcntr = 0;
          v_state = v_wait_for_vsync_0;
        }
        break;
      case v_wait_for_vsync_0:
        if (tb->vga_vsync_o == 0)
          v_state = v_wait_for_vsync_1;
        break;
      case v_wait_for_vsync_1:
        if (tb->vga_vsync_o == 1) {
          v_state = v_skip_back_porch;
          vcntr = 0;
        }
        break;
      case v_skip_back_porch:
        if (++vcntr == 33) {
          v_state = v_active_pixels;
          vcntr = 0;
          frame_done = 1;
        }
        break;
      }
    }
    break;
  case h_skip_back_porch:
    if (++hcntr == 48) {
      h_state = h_active_pixels;
      hcntr = 0;
    }
    break;
  case h_active_pixels:
    if (++hcntr == XRES) {
      h_state = h_wait_for_hsync_0;
    }
    break;
  }

  return frame_done;
}

static gboolean timeout_handler(GtkWidget *widget) {
  while (!Verilated::gotFinish()) {
    tb->clk = 1;
    tb->eval();
    if (trace) trace->dump(tick++);
    tb->clk = 0;
    tb->eval();
    if (trace) trace->dump(tick++);

    if (clk_cb()) {
      vga_frame_idx++;
      gtk_widget_queue_draw(widget);

      if (options.save_frame_from <= vga_frame_idx &&
          vga_frame_idx <= options.save_frame_to) {
        char buf[128];
        snprintf(buf, sizeof(buf), "%s_%03d.png", options.save_frame_prefix,
                 vga_frame_idx);
        gdk_pixbuf_save(vga_pixbuf, buf, "png", NULL, NULL);
      }

      if (vga_frame_idx >= options.exit_after_frame) {
        exit(0);
      }

      if (trace) trace->flush();

      return TRUE;
    }
  }

  return TRUE;
}

/* Options to add:
  --scale=N
  --frame-rate=N
  --save-frame-from=N
  --save-frame-to=N
  --save-frame-prefix=""
  --exit-after-frame=N
  --no-display
 */

static void print_usage(const char *prog) {
  fprintf(stderr, "Usage: %s [OPTIONS]\n\n", prog);
  fprintf(stderr, "  --scale=N             -- set pixel scaling\n");
  fprintf(stderr, "  --frame-rate=N        -- try to produce a new frame every N ms\n");
  fprintf(stderr, "  --save-frame-from=N   -- dump frames to .png starting from frame #N\n");
  fprintf(stderr, "  --save-frame-to=N=N   -- dump frames to .png ending with frame #N\n");
  fprintf(stderr, "  --save-frame-prefix=S -- prefix dump frame files with S\n");
  fprintf(stderr, "  --exit-after-frame=N  -- exit after frame #N\n");
  fprintf(stderr, "  --trace               -- create dump.vcd\n");
  fprintf(stderr, "\n");
}

static void parse_cmd_args(int argc, char *argv[]) {
  int off;
#define MATCH(x) (!strncmp(argv[i], x, strlen(x)) && (off = strlen(x)))
  for (int i = 1; i < argc; i++) {
    if (MATCH("--scale=")) {
      options.scale = strtol(&argv[i][off], NULL, 0);
    }
    else if (MATCH("--frame-rate=")) {
      options.frame_rate = strtol(&argv[i][off], NULL, 0);
    }
    else if (MATCH("--save-frame-from=")) {
      options.save_frame_from = strtol(&argv[i][off], NULL, 0);
    }
    else if (MATCH("--save-frame-to=")) {
      options.save_frame_to = strtol(&argv[i][off], NULL, 0);
    }
    else if (MATCH("--save-frame-prefix=")) {
      options.save_frame_prefix = &argv[i][off];
    }
    else if (MATCH("--exit-after-frame=")) {
      options.exit_after_frame = strtol(&argv[i][off], NULL, 0);
    }
    else if (MATCH("--trace")) {
      options.trace = 1;
    }
    else {
      print_usage(argv[0]);
      exit(1);
    }
  }
}

int main(int argc, char *argv[]) {

  GtkWidget *window;
  GtkWidget *darea;

  gtk_init(&argc, &argv);

  // Set default options.
  options.scale = 3;
  options.frame_rate = 1000;
  options.save_frame_from = INT_MAX;
  options.save_frame_to = INT_MAX;
  options.save_frame_prefix = "frame";
  options.exit_after_frame = INT_MAX;
  options.trace = 0;

  parse_cmd_args(argc, argv);

  window = gtk_window_new(GTK_WINDOW_TOPLEVEL);

  darea = gtk_drawing_area_new();
  gtk_container_add(GTK_CONTAINER(window), darea);

  g_signal_connect(G_OBJECT(darea), "draw", G_CALLBACK(on_draw_event), NULL);
  g_signal_connect(G_OBJECT(window), "key_press_event",
                   G_CALLBACK(on_key_press), NULL);
  g_signal_connect(G_OBJECT(window), "key_release_event",
                   G_CALLBACK(on_key_release), NULL);
  g_signal_connect(G_OBJECT(window), "destroy", G_CALLBACK(gtk_main_quit),
                   NULL);
  if (options.frame_rate) {
    g_timeout_add(options.frame_rate, (GSourceFunc)timeout_handler, window);
  } else {
    g_idle_add((GSourceFunc)timeout_handler, window);
  }

  gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
  gtk_window_set_default_size(GTK_WINDOW(window), XRES * options.scale,
                              YRES * options.scale);
  gtk_window_set_title(GTK_WINDOW(window), "VGAMon");

  gtk_widget_show_all(window);

  vga_pixbuf = gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, XRES, YRES);

  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);

  Verilated::traceEverOn(true);

  // Create an instance of our game_top under test
  tb = new Vgame_top;

  if (options.trace) {
    trace = new VerilatedVcdC;
    tb->trace(trace, 99);
    trace->open("dump.vcd");
  }

  // Apply five cycles with reset active.
  tb->rst = 1;
  for (unsigned i = 0; i < 5; i++) {
    tb->clk = 1;
    tb->eval();
    if (trace) trace->dump(tick++);
    tb->clk = 0;
    tb->eval();
    if (trace) trace->dump(tick++);
  }
  tb->rst = 0;

  gtk_main();

  return 0;
}
