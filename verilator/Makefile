TARGETS = recip16 cordic2step vgademo
VERILATOR = verilator
VERILATOR_FLAGS = -Wall --trace -cc --exe
CPP = g++
CPP_FLAGS = -std=c++11 -Wall

all: $(TARGETS)

vgademo: ../src/vgademo.v ../src/rom.v ../src/recip16.v vgademo_tb.cpp
	$(VERILATOR) -Wno-widthexpand -Wno-widthtrunc --trace -cc --exe $^ -CFLAGS "-g -O3" --LDFLAGS "-lSDL2"
	make -C obj_dir -f V$@.mk
	cp obj_dir/V$@ $@

%: ../src/%.v %_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $< $*_tb.cpp
	make -C obj_dir -f V$@.mk
	cp obj_dir/V$@ $@

clean:
	rm -rf obj_dir
	rm -f $(TARGETS)
	rm -f *.vcd

.PHONY: all clean
