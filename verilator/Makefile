VERILATOR = verilator
VERILATOR_FLAGS = -Wall --trace -cc --exe
CPP = g++
CPP_FLAGS = -std=c++11 -Wall

TARGET = recip16

all: $(TARGET)

$(TARGET): $(TARGET).v $(TARGET)_tb.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) $(TARGET).v $(TARGET)_tb.cpp
	make -C obj_dir -f V$(TARGET).mk
	cp obj_dir/V$(TARGET) .

clean:
	rm -rf obj_dir
	rm -f $(TARGET)
	rm -f *.vcd

.PHONY: all clean
