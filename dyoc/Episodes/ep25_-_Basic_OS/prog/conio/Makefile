# Include directory
INCLUDE = include


#####################################
# Compile conio library
#####################################

SOURCES := $(wildcard *.c)
SOURCES += $(wildcard *.s)

OBJECTS := $(addsuffix .o,$(basename $(SOURCES)))


build/conio.lib: $(OBJECTS)


%.o: %.c
	mkdir -p build
	cl65 $< -o $@

%.o: %.s
	mkdir -p build
	ca65 $< -o $@



#####################################
# Cleanup
#####################################

clean:
	rm -rf build
	rm -rf ../rom.txt
	rm -rf a.out
