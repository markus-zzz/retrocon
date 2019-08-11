`default_nettype none

module tb;
  reg clk;
  reg rst;

  wire vga_hsync;
  wire vga_vsync;
  wire vga_blank;
  wire vga_vactive;
  wire [9:0] vga_hpos;
  wire [9:0] vga_vpos;
  wire [31:0] gfx_vram_rdata;
  wire [10:0] gfx_vram_addr;

  reg vga_hsync_p;
  always @(posedge clk) begin
    if (rst) vga_hsync_p <= 1;
    else vga_hsync_p <= ~vga_hsync;
  end

  sprom #(
    .aw(11),
    .dw(32),
    .MEM_INIT_FILE("vram.vh")
  ) u_vram(
    .clk(clk),
    .rst(rst),
    .ce(1'b1),
    .oe(1'b1),
    .addr(gfx_vram_addr),
    .do(gfx_vram_rdata)
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
    .scanline_begin_i(vga_hsync_p & vga_hsync),
    .vram_addr_o(gfx_vram_addr),
    .vram_rdata_i(gfx_vram_rdata)
  );

  initial begin
    $dumpvars;
    clk = 0;
    rst = 1;
    #5 rst = 0;
  end

  always #1 clk <= ~clk;
endmodule
