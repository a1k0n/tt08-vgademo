# Add to existing Makefile or create a new one if it doesn't exist

VERILATOR_ROOT ?= /usr/share/verilator
VERILATOR = verilator
VERILATOR_FLAGS = -cc -Mdir obj_dir -Wno-widthtrunc -Wno-widthexpand --public

# Add your Verilog source files here
VERILOG_SOURCES = ../../../src/*.v

# C++ source files
CPP_SOURCES = verilated_vga_wrapper.cpp

# Output library name
TARGET_LIB = libverilated.a

all: $(TARGET_LIB)

$(TARGET_LIB): $(VERILOG_SOURCES) $(CPP_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_SOURCES) $(CPP_SOURCES) -top vgademo
	$(MAKE) -C obj_dir -f Vvgademo.mk
	ar -rcs $@ obj_dir/*.o

clean:
	rm -rf obj_dir $(TARGET_LIB)

.PHONY: all clean
