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

module game_top(clk, rst, vga_hsync_o, vga_vsync_o, vga_blank_o, vga_red_o, vga_green_o, vga_blue_o);
  input clk;
  input rst;
  output vga_hsync_o;
  output vga_vsync_o;
  output vga_blank_o;
  output [7:0] vga_red_o;
  output [7:0] vga_green_o;
  output [7:0] vga_blue_o;

  wire vga_hsync;
  wire vga_vsync;
  wire vga_blank;
  wire vga_vactive;
  wire [9:0] vga_hpos;
  wire [9:0] vga_vpos;
  wire [3:0] color_idx;
  reg [7:0] vga_red, vga_green, vga_blue;

  wire [31:0] gfx_vram_rdata;
  wire [10:0] gfx_vram_addr;
  wire vga_pixel_clk;

  assign vga_hsync_o = vga_hsync;
  assign vga_vsync_o = vga_vsync;
  assign vga_blank_o = vga_blank;
  assign vga_red_o = vga_red;
  assign vga_blue_o = vga_blue;
  assign vga_green_o = vga_green;

  assign vga_pixel_clk = clk;
  assign vga_vactive = vga_vsync;

  wire cpu_mem_valid;
  wire cpu_mem_instr;
  reg  ram_mem_ready;
  wire [31:0] cpu_mem_addr;
  wire [31:0] cpu_mem_wdata;
  wire [ 3:0] cpu_mem_wstrb;
  reg [31:0] cpu_mem_rdata;
  wire [31:0] ram_rdata, rom_rdata;

  always @* begin
    cpu_mem_rdata = rom_rdata;
    case (cpu_mem_addr[31:28])
      4'h0: cpu_mem_rdata = rom_rdata;
      4'h1: cpu_mem_rdata = ram_rdata;
      4'h3: cpu_mem_rdata = {31'h0, vga_vactive};
    endcase
  end

  always @(color_idx) begin
    case (color_idx)
      4'h0: begin
        // #000000 (0, 0, 0) black
        vga_red   = 0;
        vga_green = 0;
        vga_blue  = 0;
      end
      4'h1: begin
        // #1D2B53 (29, 43, 83) dark-blue
        vga_red   = 29;
        vga_green = 43;
        vga_blue  = 83;
      end
      4'h2: begin
        // #7E2553 (126, 37, 83) dark-purple
        vga_red   = 126;
        vga_green = 37;
        vga_blue  = 83;
      end
      4'h3: begin
        // #008751 (0, 135, 81) dark-green
        vga_red   = 0;
        vga_green = 135;
        vga_blue  = 81;
      end
      4'h4: begin
        // #AB5236 (171, 82, 54) brown
        vga_red   = 171;
        vga_green = 82;
        vga_blue  = 54;
      end
      4'h5: begin
        // #5F574F (95, 87, 79) dark-gray
        vga_red   = 95;
        vga_green = 87;
        vga_blue  = 79;
      end
      4'h6: begin
        // #C2C3C7 (194, 195, 199) light-gray
        vga_red   = 194;
        vga_green = 195;
        vga_blue  = 199;
      end
      4'h7: begin
        // #FFF1E8 (255, 241, 232) white
        vga_red   = 255;
        vga_green = 241;
        vga_blue  = 232;
      end
      4'h8: begin
        // #FF004D (255, 0, 77) red
        vga_red   = 255;
        vga_green = 0;
        vga_blue  = 77;
      end
      4'h9: begin
        // #FFA300 (255, 163, 0) orange
        vga_red   = 255;
        vga_green = 163;
        vga_blue  = 0;
      end
      4'ha: begin
        // #FFEC27 (255, 236, 39) yellow
        vga_red   = 255;
        vga_green = 236;
        vga_blue  = 39;
      end
      4'hb: begin
        // #00E436 (0, 228, 54) green
        vga_red   = 0;
        vga_green = 228;
        vga_blue  = 54;
      end
      4'hc: begin
        // #29ADFF (41, 173, 255) blue
        vga_red   = 41;
        vga_green = 173;
        vga_blue  = 255;
      end
      4'hd: begin
        // #83769C (131, 118, 156) indigo
        vga_red   = 131;
        vga_green = 118;
        vga_blue  = 156;
      end
      4'he: begin
        // #FF77A8 (255, 119, 168) pink
        vga_red   = 255;
        vga_green = 119;
        vga_blue  = 168;
      end
      4'hf: begin
        // #FFCCAA (255, 204, 170) peach
        vga_red   = 255;
        vga_green = 204;
        vga_blue  = 170;
      end
    endcase
  end

  reg vga_hsync_p;
  always @(posedge clk) begin
    if (rst) vga_hsync_p <= 1;
    else vga_hsync_p <= ~vga_hsync;
  end

  // VRAM - rationale behind dimension and  memory map.
  //
  // Each sprite/tile is 8x8 pixel with a color depth of 4 bits giving it a
  // storage requirement of 32 bytes. We need at least 128 of these in VRAM so
  // that results in 4096 bytes.
  //
  // Each sprite descriptor is 32 bits wide and we need 64 of those, i.e. 256
  // bytes.
  //
  // With a screen resolution of 320x200 and sprite/tile size of 8x8 a total of
  // 40x30 tiles are needed to cover the screen using a 8 bit index for each
  // results in 1200 bytes. Since we want to be able to index this memory
  // without performing multiplication the dimension is rounded up to the
  // nearest power-of-two i.e. 64x32 resulting in 2048 bytes.
  //
  // These extra rows and coulmns may come in handy whey trying to support
  // smooth scrolling.
  //
  // All in all it is reasonable to dimension the VRAM to 8192 bytes. To allow
  // efficient 32 bit access from both GFX and CPU this is laid out as 2048 x
  // 32 meaning that we need an address bus width of 11 bits.
  spram #(
    .aw(11),
    .dw(32)
  ) u_vram(
    .clk(clk),
    .rst(rst),
    .ce(vga_vactive || cpu_mem_addr[31:28] == 4'h2),
    .oe(1'b1),
    .addr(vga_vactive ? gfx_vram_addr : cpu_mem_addr[12:2]),
    .do(gfx_vram_rdata),
    .di(cpu_mem_wdata),
    .we(cpu_mem_wstrb != 4'h0 && ~vga_vactive)
  );


  vga_video vga_instance
  (
    .clk(clk),
    .resetn(~rst),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_blank(vga_blank),
    .h_pos(vga_hpos),
    .v_pos(vga_vpos)
  );


  gfx u_gfx(
    .clk(clk),
    .rst(rst),
    .video_vpos_i(vga_vpos),
    .video_hpos_i(vga_hpos),
    .color_o(color_idx),
    .vram_addr_o(gfx_vram_addr),
    .vram_rdata_i(gfx_vram_rdata)
  );

  always @(posedge clk) begin
    if (rst) ram_mem_ready <= 0;
    else ram_mem_ready <= ~ram_mem_ready & cpu_mem_valid & (~vga_vactive || cpu_mem_addr[31:28] != 4'h2);
  end

  sprom #(
    .aw(12),
    .MEM_INIT_FILE("rom.vh")
  ) u_rom(
    .clk(clk),
    .rst(rst),
    .ce(cpu_mem_addr[31:28] == 4'h0),
    .oe(1'b1),
    .addr(cpu_mem_addr[12:2]),
    .do(rom_rdata)
  );


  spram #(
    .dw(8)
  ) u_ram_0(
    .clk(clk),
    .rst(rst),
    .ce(cpu_mem_addr[31:28] == 4'h1),
    .oe(1'b1),
    .addr(cpu_mem_addr[11:2]),
    .do(ram_rdata[7:0]),
    .di(cpu_mem_wdata[7:0]),
    .we(cpu_mem_wstrb[0])
  );

  spram #(
    .dw(8)
  ) u_ram_1(
    .clk(clk),
    .rst(rst),
    .ce(cpu_mem_addr[31:28] == 4'h1),
    .oe(1'b1),
    .addr(cpu_mem_addr[11:2]),
    .do(ram_rdata[15:8]),
    .di(cpu_mem_wdata[15:8]),
    .we(cpu_mem_wstrb[1])
  );

  spram #(
    .dw(8)
  ) u_ram_2(
    .clk(clk),
    .rst(rst),
    .ce(cpu_mem_addr[31:28] == 4'h1),
    .oe(1'b1),
    .addr(cpu_mem_addr[11:2]),
    .do(ram_rdata[23:16]),
    .di(cpu_mem_wdata[23:16]),
    .we(cpu_mem_wstrb[2])
  );

  spram #(
    .dw(8)
  ) u_ram_3(
    .clk(clk),
    .rst(rst),
    .ce(cpu_mem_addr[31:28] == 4'h1),
    .oe(1'b1),
    .addr(cpu_mem_addr[11:2]),
    .do(ram_rdata[31:24]),
    .di(cpu_mem_wdata[31:24]),
    .we(cpu_mem_wstrb[3])
  );

  picorv32 #(
    .STACKADDR(32'h1000_0200)
  ) u_cpu(
    .clk(clk),
    .resetn(~rst),
    .mem_valid(cpu_mem_valid),
    .mem_instr(cpu_mem_instr),
    .mem_ready(ram_mem_ready),
    .mem_addr(cpu_mem_addr),
    .mem_wdata(cpu_mem_wdata),
    .mem_wstrb(cpu_mem_wstrb),
    .mem_rdata(cpu_mem_rdata)
  );

endmodule
