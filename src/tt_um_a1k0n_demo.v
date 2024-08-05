`default_nettype none

module tt_um_a1k0n_demo(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire R;
  wire G;
  wire B;

  vgademo vgademo(
    .clk48(clk),
    .vsync(vsync),
    .hsync(hsync),
    .r_out(R),
    .g_out(G),
    .b_out(B),
    .rst_n(rst_n),
    .pause_n(!ui_in[7])  // flip in7 on to pause demo
  );

  // TinyVGA PMOD
  assign uo_out = {hsync, B, G, R, vsync, B, G, R};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

endmodule
