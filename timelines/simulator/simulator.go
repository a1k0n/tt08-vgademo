package simulator

// #cgo CFLAGS: -I../verilator/vgademo
// #cgo LDFLAGS: -L../verilator/vgademo -lverilated
// #include "verilated_vga.h"
import "C"
import "unsafe"

type Simulator struct {
	vga *C.VerilatedVgaTop
}

func NewSimulator() *Simulator {
	return &Simulator{
		vga: C.verilated_vga_init(),
	}
}

func (s *Simulator) Step() int {
	return int(C.verilated_vga_eval(s.vga))
}

func (s *Simulator) SetParams(frame int, xpos int, p3 int, p4 int, p5 int) {
	C.verilated_vga_set_params(s.vga, C.int(frame), C.int(xpos), C.int(p3), C.int(p4), C.int(p5))
}

func (s *Simulator) GetFramebuffer() []byte {
	cFramebuffer := C.verilated_vga_get_framebuffer(s.vga)
	// Assuming the framebuffer is 1220x960 pixels, 4 bytes per pixel (RGBA)
	framebufferSize := 1220 * 960 * 4
	return C.GoBytes(unsafe.Pointer(cFramebuffer), C.int(framebufferSize))
}

func (s *Simulator) Finish() {
	C.verilated_vga_finish(s.vga)
}
