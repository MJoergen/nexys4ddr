# Include directory
INCLUDE = include


#####################################
# Compile conio library
#####################################

SOURCES := $(wildcard *.c)
SOURCES += $(wildcard *.s)

#OBJECTS := $(addsuffix .o,$(basename $(SOURCES)))
OBJECTS := $(addsuffix .o, $(basename $(addprefix build/, $(SOURCES))))

CFLAGS = -O
INCLUDE = -I ../include -I .

.SUFFIXES:
.PHONY: all

all: build/conio.lib

build:
	mkdir -p $@

build/%.o: %.c | build
	cl65 -c $(CFLAGS) $(INCLUDE) -o $@ $<

build/%.o: %.s | build
	cl65 -c $(ASFLAGS) -o $@ $<

build/conio.lib: $(OBJECTS)
	ar65 r $@ $^


#####################################
# Cleanup
#####################################

clean:
	rm -rf build

