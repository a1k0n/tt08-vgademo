#include "verilated_vga.h"
#include "Vvgademo.h"
#include "verilated.h"
#include <memory>

// Include any other necessary headers from vgademo_tb.cpp

// Note: the VGA screen here is in a custom resolution of 1220x480
// and the full VGA timing (from vgademo.v) is:
// horizontal clocks: 1525
// vertical clocks: 525

struct VerilatedVgaTop {
  std::unique_ptr<Vvgademo> top;
  // Add any other necessary members from vgademo_tb.cpp
  uint32_t* framebuffer;
  int framebuffer_size;
};

VerilatedVgaTop* verilated_vga_init() {
  auto vga = new VerilatedVgaTop();
  vga->top = std::make_unique<Vvgademo>();
  // Initialize other members and setup as needed
  vga->framebuffer_size = 1220 * 480 * 2;
  vga->framebuffer = new uint32_t[vga->framebuffer_size];
  // clock a reset
  vga->top->rst_n = 1;
  vga->top->eval();
  vga->top->rst_n = 0;
  vga->top->eval();
  vga->top->rst_n = 1;
  return vga;
}

static inline uint32_t lowextend6(uint32_t x) {
  // take a 2-bit input, shift left extending to 8 bits, but cloning into the
  // remaining 6 bits
  // 00 -> 00000000
  // 01 -> 01010101
  // 10 -> 10101010
  // 11 -> 11111111
  return (x << 6) | (x << 4) | (x << 2) | x;
}

void verilated_vga_eval(VerilatedVgaTop* vga) {
  // Implement the evaluation logic from vgademo_tb.cpp
  int k = 0;
  for (int j = 0; j < 525; j++) {
    for (int i = 0; i < 1525; i++) {
      vga->top->clk48 = 1;
      vga->top->eval();
      vga->top->clk48 = 0;
      vga->top->eval();
      if (i < 1220 && j < 480) {
        // RGBA order in bytes
        uint32_t r = lowextend6(vga->top->r_out);
        uint32_t g = lowextend6(vga->top->g_out) << 8;
        uint32_t b = lowextend6(vga->top->b_out) << 16;
        uint32_t color = 0x8F000000 | r | g | b;
        vga->framebuffer[k] = color;
        vga->framebuffer[k + 1220] = color;
        k++;
      }
    }
    k += 1220;
  }
}

unsigned char* verilated_vga_get_framebuffer(VerilatedVgaTop* vga) {
  // Implement framebuffer access logic
  // This will depend on how the framebuffer is stored in your Verilator model
  // Return a pointer to the framebuffer data
  return (unsigned char*)vga->framebuffer;
}

void verilated_vga_finish(VerilatedVgaTop* vga) {
  // Clean up resources
  delete[] vga->framebuffer;
  delete vga;
}
