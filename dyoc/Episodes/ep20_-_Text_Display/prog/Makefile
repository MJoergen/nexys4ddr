# Include directory
C_INC = .


#####################################
# Compile target program
#####################################

../rom.txt: build/rom.bin
	./bin2hex.py $< $@

build/rom.bin: build/main.o build/vectors.o build/comp.lib
	ld65 -m build/rom.map -C ld.cfg $^

build/main.o: build/main.s
	ca65 $< -o $@

build/main.s: main.c
	mkdir -p build
	cc65 -g -t none -O $< -o $@


#####################################
# Compile runtime library
#####################################

build/comp.lib: build/crt0.o build/printf.o
	cp lib/none.lib $@
	ar65 r $@ $^

build/printf.o: build/printf.s
	ca65 $< -o $@

build/printf.s: lib/printf.c
	cc65 -I $(C_INC) -g -t none -O $< -o $@

build/crt0.o: lib/crt0.s           # Reset vector
	mkdir -p build
	ca65 $< -o $@

build/vectors.o: lib/vectors.s     # Hardware interrupt vectors
	mkdir -p build
	ca65 $< -o $@


#####################################
# Cleanup
#####################################

clean:
	rm -rf build
	rm -rf ../rom.txt
	rm -rf a.out
