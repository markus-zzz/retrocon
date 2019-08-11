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

module video_timgen(clk, rst, hsync_o, vsync_o, hcntr_o, vcntr_o, vactive_o);

  // XXX: We could extract the comparators into separate assign statements to
  // get a better overview of how many are used.

  parameter HSIZE = 10;
  parameter VSIZE = 10;

  input clk;
  input rst;
  output hsync_o;
  output vsync_o;
  output [HSIZE-1:0] hcntr_o;
  output [VSIZE-1:0] vcntr_o;
  output vactive_o;

  reg hsync;
  reg vsync;
  reg [HSIZE-1:0] hcntr;
  reg [VSIZE-1:0] vcntr;
  reg vactive;

  assign hsync_o = hsync;
  assign vsync_o = vsync;
  assign hcntr_o = hcntr;
  assign vcntr_o = vcntr;
  assign vactive_o = vactive;

  // Horizontal timings in pixels.
  localparam [HSIZE-1:0] h_front_porch_width = 16;
  localparam [HSIZE-1:0] h_sync_width = 96;
  localparam [HSIZE-1:0] h_back_porch_width = 48;
  localparam [HSIZE-1:0] h_active_width = 640;
  localparam [HSIZE-1:0] h_blank_width = h_front_porch_width + h_sync_width + h_back_porch_width;
  localparam [HSIZE-1:0] h_total_width = h_active_width + h_blank_width;

  // Vertical timings in lines.
  localparam [VSIZE-1:0] v_active_width = 480;
  localparam [VSIZE-1:0] v_front_porch_width = 10;
  localparam [VSIZE-1:0] v_sync_width = 2;
  localparam [VSIZE-1:0] v_back_porch_width = 33;
  localparam [VSIZE-1:0] v_blank_width = v_front_porch_width + v_sync_width + v_back_porch_width;
  localparam [VSIZE-1:0] v_total_width = v_active_width + v_blank_width;

  // Generate horizontal counter.
  always @(posedge clk) begin
    if (rst || hcntr == h_active_width) begin
      hcntr <= -h_blank_width;
    end
    else begin
      hcntr <= hcntr + 1;
    end
  end

  // Generate vertical counter.
  always @(posedge clk) begin
    if (rst || (vcntr == v_total_width && hcntr == h_active_width)) begin
      vcntr <= 0;
    end
    else if (hcntr == h_active_width) begin
      vcntr <= vcntr + 1;
    end
  end

  // Generate horizontal sync.
  always @(posedge clk) begin
    if (rst) begin
      hsync <= 1;
    end
    else begin
      if (hcntr == -(h_sync_width + h_back_porch_width))
        hsync <= 0;
      if (hcntr == -h_back_porch_width)
        hsync <= 1;
    end
  end

  // Generate vertical sync.
  always @(posedge clk) begin
    if (rst) begin
      vsync <= 1;
    end
    else if (hcntr == h_active_width) begin
      if (vcntr == (v_active_width + v_front_porch_width))
        vsync <= 0;
      if (vcntr == (v_active_width + v_front_porch_width + v_sync_width))
        vsync <= 1;
    end
  end

  // Generate vertical active.
  always @(posedge clk) begin
    if (rst || (vcntr == v_total_width && hcntr == h_active_width)) begin
      vactive <= 1;
    end
    else if (vcntr == (v_active_width + v_front_porch_width)) begin
      // XXX: Actually could skip the front porch but I want to reuse an
      // existing comparator.
      vactive <= 0;
    end
  end

endmodule
