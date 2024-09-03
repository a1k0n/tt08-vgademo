#ifndef VERILATED_VGA_H
#define VERILATED_VGA_H

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer to the Verilated model
typedef struct VerilatedVgaTop VerilatedVgaTop;

// Initialize the Verilated model
VerilatedVgaTop* verilated_vga_init();

// Evaluate the model for one clock cycle
void verilated_vga_eval(VerilatedVgaTop* top);

// Get the current framebuffer data
unsigned char* verilated_vga_get_framebuffer(VerilatedVgaTop* top);

// Clean up and free resources
void verilated_vga_finish(VerilatedVgaTop* top);

#ifdef __cplusplus
}
#endif

#endif // VERILATED_VGA_H