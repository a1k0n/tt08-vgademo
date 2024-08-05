module demo_orangecrab (
    input clk48,
    input usr_btn,
    output gpio_0,  // vsync
    output gpio_1,  // hsync
    output gpio_a0, // Blue
    output gpio_a1, // Green
    output gpio_a2  // Red
);

vgademo vgademo(
  .vsync(gpio_0),
  .hsync(gpio_1),
  .b_out(gpio_a0),
  .g_out(gpio_a1),
  .r_out(gpio_a2),
  .clk48(clk48),
  .pause_n(usr_btn),
  .rst_n(1)
);

endmodule
