# Compiler flags
CFLAGS = -O
INCLUDE = -I include

#####################################
# Compile target program
#####################################

../rom.txt: build/rom.bin
	./bin2hex.py $< $@

build/rom.bin: build/main.o build/vectors.o conio/build/conio.lib runtime/build/runtime.lib
	ld65 -m build/rom.map -C ld.cfg --start-group $^ --end-group

build:
	mkdir -p $@

build/main.o: src/main.c | build
	cl65 -t none -c $(CFLAGS) $(INCLUDE) -o $@ $<


#####################################
# Compile conio library
#####################################
conio/build/conio.lib:
	make -C conio

#####################################
# Compile runtime library
#####################################
runtime/build/runtime.lib:
	make -C runtime


build/vectors.o: runtime/vectors.s     # Hardware interrupt vectors
	mkdir -p build
	ca65 $< -o $@


#####################################
# Cleanup
#####################################

clean:
	rm -rf build
	rm -rf conio/build
	rm -rf runtime/build
	rm -rf ../rom.txt
	rm -rf a.out
