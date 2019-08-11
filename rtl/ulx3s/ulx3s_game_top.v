module ulx3s_game_top(input clk_25mhz,
		      output [3:0] gpdi_dp, gpdi_dn,
		      output wifi_gpio0);

  wire vga_vsync, vga_hsync, vga_blank;
  wire [7:0] vga_red, vga_green, vga_blue;
  wire clk_locked;

  assign wifi_gpio0 = 1'b1;

    // clock generator
    wire clk_250MHz, clk_125MHz, clk_25MHz;
    clk_25_250_125_25
    clock_instance
    (
      .clki(clk_25mhz),
      .clko(clk_250MHz),
      .clks1(clk_125MHz),
      .clks2(clk_25MHz),
      .locked(clk_locked)
    );

    // VGA to digital video converter
    wire [1:0] tmds[3:0];
    vga2dvid vga2dvid_instance
    (
      .clk_pixel(clk_25MHz),
      .clk_shift(clk_125MHz),
      .in_color({vga_red, vga_green, vga_blue}),
      .in_hsync(vga_hsync),
      .in_vsync(vga_vsync),
      .in_blank(vga_blank),
      .out_clock(tmds[3]),
      .out_red(tmds[2]),
      .out_green(tmds[1]),
      .out_blue(tmds[0]),
      .resetn(clk_locked),
    );

    // output TMDS SDR/DDR data to fake differential lanes
    fake_differential fake_differential_instance
    (
      .clk_shift(clk_125MHz),
      .in_clock(tmds[3]),
      .in_red(tmds[2]),
      .in_green(tmds[1]),
      .in_blue(tmds[0]),
      .out_p(gpdi_dp),
      .out_n(gpdi_dn)
    );

  game_top top_u(
    .clk(clk_25mhz),
    .rst(~clk_locked),
    .vga_hsync_o(vga_hsync),
    .vga_vsync_o(vga_vsync),
    .vga_blank_o(vga_blank),
    .vga_red_o(vga_red),
    .vga_green_o(vga_green),
    .vga_blue_o(vga_blue)
  );

endmodule


