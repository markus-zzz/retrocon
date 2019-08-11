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

`define SPRITE_DESC_VPOS 7:0
`define SPRITE_DESC_HPOS 16:8
`define SPRITE_DESC_IDX 24:17
`define SPRITE_DESC_VFLIP 29
`define SPRITE_DESC_HFLIP 30
`define SPRITE_DESC_ACTIVE 31

module gfx(clk, rst, video_vpos_i, video_hpos_i, color_o, vram_addr_o, vram_rdata_i);
  input clk;
  input rst;
  input [9:0] video_vpos_i;
  input [9:0] video_hpos_i;
  output [3:0] color_o;
  input [31:0] vram_rdata_i;
  output [10:0] vram_addr_o;

  wire [31:0] vram_rdata;
  reg [10:0] vram_addr;

  wire [31:0] sprite_desc;
  reg  [31:0] sprite_desc_p;

  wire [7:0] sprite_vdiff;

  reg [6:0] desc_idx;
  reg [3:0] slot_idx;

  wire [3:0] tile_color;

  wire [8:0] screen_hpos;
  reg [7:0] screen_vpos;
  wire screen_pixel_clk_en;

  assign screen_hpos = video_hpos_i[9:1];
//  assign screen_vpos = video_vpos_i[8:1];
  assign screen_pixel_clk_en = ~video_hpos_i[0];

  always @(posedge clk) begin
    // Doing this addition here seems stupid. Should do it already in the VGA module?
    if (screen_hpos == 320) screen_vpos <= video_vpos_i[8:1] + 8'h1;
  end

  localparam VRAM_BITMAPS_BASE = 11'd0,
             VRAM_SPRITES_BASE = VRAM_BITMAPS_BASE + 11'd1024,
             VRAM_TILES_BASE   = VRAM_SPRITES_BASE + 11'd64;

  assign vram_addr_o = vram_addr;
  assign vram_rdata = vram_rdata_i;
  assign sprite_desc = vram_rdata;

  assign sprite_vdiff = screen_vpos - sprite_desc[`SPRITE_DESC_VPOS];

  reg [7:0] tile_idx;

  always @* begin
    case (screen_hpos[4:3])
      2'b00: tile_idx = vram_rdata[7:0];
      2'b01: tile_idx = vram_rdata[15:8];
      2'b10: tile_idx = vram_rdata[23:16];
      2'b11: tile_idx = vram_rdata[31:24];
    endcase
  end

  always @* begin
    case (next_state)
      S_PIXEL_READ_0: begin
        vram_addr = VRAM_BITMAPS_BASE + {sprite_desc[`SPRITE_DESC_IDX], sprite_vdiff[2:0]};
      end
      S_TILE_TBL_READ: begin
        //vram_addr = VRAM_TILES_BASE + {screen_hpos[8:3], screen_vpos[7:3]}; // Note that this means row/col major with 40x32 elements or something. Need to check this!
        vram_addr = VRAM_TILES_BASE + {2'h0, screen_vpos[7:3], screen_hpos[8:5]};
      end
      S_TILE_PIXEL_READ: begin
        vram_addr = VRAM_BITMAPS_BASE + {tile_idx, screen_vpos[2:0]};
      end
      default: begin
        vram_addr = VRAM_SPRITES_BASE + {3'h0, desc_idx};
      end
    endcase
  end

  localparam S_IDLE = 1 << 0,
             S_DESC_READ_0 = 1 << 1,
             S_PIXEL_READ_0 = 1 << 2,
             S_WAIT_ACTIVE = 1 << 3,
             S_WAIT_TILE = 1 << 4,
             S_TILE_TBL_READ = 1 << 5,
             S_TILE_PIXEL_READ = 1 << 6;

  reg [7:0] curr_state, next_state;

  always @(posedge clk) begin
    if (rst) curr_state <= S_IDLE;
    else curr_state <= next_state;
  end

  always @(posedge clk) begin
    if (rst || next_state == S_IDLE) desc_idx <= 0;
    else if (next_state == S_DESC_READ_0) desc_idx <= desc_idx + 1;
  end

  always @(posedge clk) begin
    if (rst || next_state == S_IDLE) slot_idx <= 0;
    else if (curr_state == S_PIXEL_READ_0) slot_idx <= slot_idx + 1;
  end

  always @* begin
    next_state = curr_state;
    case (curr_state)
      S_IDLE: begin
        if (screen_hpos == 320) next_state = S_DESC_READ_0;
      end
      S_DESC_READ_0: begin
        if (sprite_desc[`SPRITE_DESC_ACTIVE] && sprite_vdiff < 8 && slot_idx < 8) next_state = S_PIXEL_READ_0;
        else if (desc_idx < 64) next_state = S_DESC_READ_0;
        else next_state = S_WAIT_ACTIVE /*S_IDLE*/;
      end
      S_PIXEL_READ_0: begin
        if (desc_idx < 64) next_state = S_DESC_READ_0;
        else next_state = S_WAIT_ACTIVE /*S_IDLE*/;
      end

      S_WAIT_ACTIVE: begin
        if (screen_hpos == 0) next_state = S_WAIT_TILE;
      end
      S_WAIT_TILE: begin
        if (screen_hpos == 320) next_state = S_IDLE;
        else if (screen_hpos[2:0] == 0) next_state = S_TILE_TBL_READ;
      end
      S_TILE_TBL_READ: begin
        next_state = S_TILE_PIXEL_READ;
      end
      S_TILE_PIXEL_READ: begin
        next_state = S_WAIT_TILE;
      end

    endcase
  end

  always @(posedge clk) begin
    if (rst) sprite_desc_p <= 0;
    else if (curr_state == S_DESC_READ_0) sprite_desc_p <= sprite_desc;
  end

  // Generate eight sprite shifters.
  wire [3:0] colors[0:7];
  genvar gi;
  generate
    for (gi=0; gi<8; gi=gi+1) begin : sprite_shifter
      sprite_shifter sh(
        .clk(clk),
        .rst(rst),
        .pixel_clk_en(screen_pixel_clk_en),
        .hpos_i(screen_hpos),
        .sprite_hpos_i(sprite_desc_p[`SPRITE_DESC_HPOS]),
        .sprite_pixels_i(vram_rdata),
        .sprite_load_en_i(curr_state == S_PIXEL_READ_0 && slot_idx == gi),
        .color_o(colors[gi])
      );
    end
  endgenerate

  // Sprite #0 has highest priority, Sprite #7 has lowest priority.
  assign color_o = colors[0] != 4'h0 ? colors[0] :
                   colors[1] != 4'h0 ? colors[1] :
                   colors[2] != 4'h0 ? colors[2] :
                   colors[3] != 4'h0 ? colors[3] :
                   colors[4] != 4'h0 ? colors[4] :
                   colors[5] != 4'h0 ? colors[5] :
                   colors[6] != 4'h0 ? colors[6] :
                   colors[7] != 4'h0 ? colors[7] :
                   tile_color;

  tile_shifter u_ts(
    .clk(clk),
    .rst(rst),
    .pixel_clk_en(screen_pixel_clk_en),
    .tile_pixels_i(vram_rdata),
    .tile_load_en_i(curr_state == S_TILE_PIXEL_READ),
    .color_o(tile_color)
  );

endmodule

module sprite_shifter(clk, rst, pixel_clk_en, hpos_i, sprite_hpos_i, sprite_pixels_i, sprite_load_en_i, color_o);

  input clk;
  input rst;
  input pixel_clk_en;
  input [8:0] hpos_i;
  input [8:0] sprite_hpos_i;
  input [31:0] sprite_pixels_i;
  input sprite_load_en_i;
  output [3:0] color_o;

  reg triggered;

  reg [8:0] sprite_hpos;

  reg [7:0] sprite_pixels_0;
  reg [7:0] sprite_pixels_1;
  reg [7:0] sprite_pixels_2;
  reg [7:0] sprite_pixels_3;

  assign color_o = {sprite_pixels_0[7] & triggered,
                    sprite_pixels_1[7] & triggered,
                    sprite_pixels_2[7] & triggered,
                    sprite_pixels_3[7] & triggered};

  always @(posedge clk) begin
    if (rst) begin
      sprite_hpos <= 0;
    end
    else if (sprite_load_en_i) begin
      sprite_hpos <= sprite_hpos_i;
    end
  end

  always @(posedge clk) begin
    if (rst | sprite_load_en_i) begin
      triggered <= 0;
    end
    else if (hpos_i == sprite_hpos && pixel_clk_en) begin
      triggered <= 1;
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      sprite_pixels_0 <= 0;
      sprite_pixels_1 <= 0;
      sprite_pixels_2 <= 0;
      sprite_pixels_3 <= 0;
    end
    else if (sprite_load_en_i) begin
      sprite_pixels_3 <= {sprite_pixels_i[28], sprite_pixels_i[24], sprite_pixels_i[20], sprite_pixels_i[16],
                          sprite_pixels_i[12], sprite_pixels_i[8], sprite_pixels_i[4], sprite_pixels_i[0]};
      sprite_pixels_2 <= {sprite_pixels_i[29], sprite_pixels_i[25], sprite_pixels_i[21], sprite_pixels_i[17],
                          sprite_pixels_i[13], sprite_pixels_i[9], sprite_pixels_i[5], sprite_pixels_i[1]};
      sprite_pixels_1 <= {sprite_pixels_i[30], sprite_pixels_i[26], sprite_pixels_i[22], sprite_pixels_i[18],
                          sprite_pixels_i[14], sprite_pixels_i[10], sprite_pixels_i[6], sprite_pixels_i[2]};
      sprite_pixels_0 <= {sprite_pixels_i[31], sprite_pixels_i[27], sprite_pixels_i[23], sprite_pixels_i[19],
                          sprite_pixels_i[15], sprite_pixels_i[11], sprite_pixels_i[7], sprite_pixels_i[3]};
    end
    else if (triggered & pixel_clk_en) begin
      sprite_pixels_0 <= {sprite_pixels_0[6:0], 1'b0};
      sprite_pixels_1 <= {sprite_pixels_1[6:0], 1'b0};
      sprite_pixels_2 <= {sprite_pixels_2[6:0], 1'b0};
      sprite_pixels_3 <= {sprite_pixels_3[6:0], 1'b0};
    end
  end

endmodule

module tile_shifter(clk, rst, pixel_clk_en, tile_pixels_i, tile_load_en_i, color_o);

  input clk;
  input rst;
  input pixel_clk_en;
  input [31:0] tile_pixels_i;
  input tile_load_en_i;
  output [3:0] color_o;

  reg [7:0] tile_pixels_0;
  reg [7:0] tile_pixels_1;
  reg [7:0] tile_pixels_2;
  reg [7:0] tile_pixels_3;

  assign color_o = {tile_pixels_0[7],
                    tile_pixels_1[7],
                    tile_pixels_2[7],
                    tile_pixels_3[7]};

  always @(posedge clk) begin
    if (rst) begin
      tile_pixels_0 <= 0;
      tile_pixels_1 <= 0;
      tile_pixels_2 <= 0;
      tile_pixels_3 <= 0;
    end
    else if (tile_load_en_i) begin
      tile_pixels_3 <= {tile_pixels_i[28], tile_pixels_i[24], tile_pixels_i[20], tile_pixels_i[16],
                          tile_pixels_i[12], tile_pixels_i[8], tile_pixels_i[4], tile_pixels_i[0]};
      tile_pixels_2 <= {tile_pixels_i[29], tile_pixels_i[25], tile_pixels_i[21], tile_pixels_i[17],
                          tile_pixels_i[13], tile_pixels_i[9], tile_pixels_i[5], tile_pixels_i[1]};
      tile_pixels_1 <= {tile_pixels_i[30], tile_pixels_i[26], tile_pixels_i[22], tile_pixels_i[18],
                          tile_pixels_i[14], tile_pixels_i[10], tile_pixels_i[6], tile_pixels_i[2]};
      tile_pixels_0 <= {tile_pixels_i[31], tile_pixels_i[27], tile_pixels_i[23], tile_pixels_i[19],
                          tile_pixels_i[15], tile_pixels_i[11], tile_pixels_i[7], tile_pixels_i[3]};
    end
    else if (pixel_clk_en) begin
      tile_pixels_0 <= {tile_pixels_0[6:0], 1'b0};
      tile_pixels_1 <= {tile_pixels_1[6:0], 1'b0};
      tile_pixels_2 <= {tile_pixels_2[6:0], 1'b0};
      tile_pixels_3 <= {tile_pixels_3[6:0], 1'b0};
    end
  end

endmodule
