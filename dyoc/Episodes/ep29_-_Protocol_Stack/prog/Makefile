PROGRAM = date65

# Compiler flags
CFLAGS = -O

# Assembler flags
ASFLAGS = -DTCP

# Add program sources
SOURCES += $(wildcard $(PROGRAM)/*.c)
SOURCES += $(wildcard $(PROGRAM)/*.s)

# Add conio sources
LIBSOURCES += $(wildcard conio/*.c)
LIBSOURCES += $(wildcard conio/*.s)

# Add runtime sources
LIBSOURCES += $(wildcard runtime/*.c)
LIBSOURCES += $(wildcard runtime/*.s)

# Add ip65 sources
LIBSOURCES += $(wildcard ip65/*.s)

# Specify include directories
INCLUDE = -I inc

# Generate list of object files
OBJECTS := $(sort $(addsuffix .o, $(basename $(addprefix build/, $(SOURCES)))))

# Generate list of object files
LIBOBJECTS := $(sort $(addsuffix .o, $(basename $(addprefix build/, $(LIBSOURCES)))))


#####################################
# Compile target program
#####################################

../rom.txt: build/rom.bin
	./bin2hex.py $< $@

build/rom.bin: $(OBJECTS) build/runtime/vectors.o build/comp.lib
	ld65 -m build/rom.map -C ld.cfg $^


build/%.o: %.c | build build/ip65 build/conio build/runtime build/$(PROGRAM)
	cl65 -t none -c $(CFLAGS) $(INCLUDE) -o $@ $<

build/%.o: %.s | build build/ip65 build/conio build/runtime build/$(PROGRAM)
	cl65 -t none -c $(ASFLAGS) -o $@ $<

build/comp.lib: $(LIBOBJECTS)
	cp runtime/none.lib $@
	ar65 r $@ $^

build:
	mkdir -p $@

build/ip65:
	mkdir -p $@

build/conio:
	mkdir -p $@

build/runtime:
	mkdir -p $@

build/$(PROGRAM):
	mkdir -p $@


#####################################
# Generate bit-file and program FPGA
#####################################

XILINX_ISE_DIR = /opt/Xilinx/14.7/ISE_DS
BIT = ../fpga/comp.bit
BMM = ../fpga/comp.bmm
ROM = ../rom.txt
MEM = comp.mem

comp.bit: $(BIT) $(BMM) $(MEM)
	bash -c "source $(XILINX_ISE_DIR)/settings64.sh ; data2mem -bm $(BMM) -bt $(BIT) -bd $(MEM) -o b comp.bit"

$(MEM): $(ROM)
	echo "@C000" > $(MEM)
	cat $(ROM) >> $(MEM)

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Cleanup
#####################################

clean:
	rm -rf build
	rm -rf ../rom.txt
	rm -rf a.out
	rm -rf comp.bit
	rm -rf comp.mem

