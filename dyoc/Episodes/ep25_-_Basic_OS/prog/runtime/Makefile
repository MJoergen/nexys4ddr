# Library name
LIB = runtime

SOURCES := $(wildcard *.c)
SOURCES += $(wildcard *.s)

#OBJECTS := $(addsuffix .o,$(basename $(SOURCES)))
OBJECTS := $(addsuffix .o, $(basename $(addprefix build/, $(SOURCES))))

CFLAGS = -O
INCLUDE = -I ../include -I .

.SUFFIXES:
.PHONY: all

all: build/$(LIB).lib

build:
	mkdir -p $@

build/%.o: %.c | build
	cl65 -t none -c $(CFLAGS) $(INCLUDE) -o $@ $<

build/%.o: %.s | build
	cl65 -t none -c $(ASFLAGS) -o $@ $<

build/$(LIB).lib: $(OBJECTS)
	cp none.lib $@
	ar65 r $@ $^


#####################################
# Cleanup
#####################################

clean:
	rm -rf build

