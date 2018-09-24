PROGRAM = ethernet

# Compiler flags
CFLAGS = -O

# Add program sources
SOURCES += $(wildcard $(PROGRAM)/*.c)
SOURCES += $(wildcard $(PROGRAM)/*.s)

# Add conio sources
LIBSOURCES += $(wildcard conio/*.c)
LIBSOURCES += $(wildcard conio/*.s)

# Add runtime sources
LIBSOURCES += $(wildcard runtime/*.c)
LIBSOURCES += $(wildcard runtime/*.s)

# Specify include directories
INCLUDE = -I include

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


build/%.o: %.c | build build/conio build/runtime build/$(PROGRAM)
	cl65 -t none -c $(CFLAGS) $(INCLUDE) -o $@ $<

build/%.o: %.s | build build/conio build/runtime build/$(PROGRAM)
	cl65 -t none -c $(ASFLAGS) -o $@ $<

build/comp.lib: $(LIBOBJECTS)
	cp runtime/none.lib $@
	ar65 r $@ $^

build:
	mkdir -p $@

build/conio:
	mkdir -p $@

build/runtime:
	mkdir -p $@

build/$(PROGRAM):
	mkdir -p $@


#####################################
# Cleanup
#####################################

clean:
	rm -rf build
	rm -rf ../rom.txt
	rm -rf a.out
