# Include directory
INCLUDE = include


#####################################
# Compile target program
#####################################

../rom.txt: build/rom.bin
	./bin2hex.py $< $@

build/rom.bin: build/main.o build/vectors.o build/comp.lib
	ld65 -m build/rom.map -C ld.cfg $^

build/main.o: build/main.s
	ca65 $< -o $@

build/main.s: src/main.c
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@


#####################################
# Compile runtime library
#####################################

build/comp.lib: build/crt0.o build/write.o build/kbd_isr.o \
					 build/vga_isr.o build/irq.o build/keyboard.o 
	cp lib/none.lib $@
	ar65 r $@ $^

build/keyboard.o: build/keyboard.s
	ca65 $< -o $@

build/keyboard.s: lib/keyboard.c
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/write.o: build/write.s
	ca65 $< -o $@

build/write.s: lib/write.c
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/kbd_isr.o: lib/kbd_isr.s     # KBD interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/vga_isr.o: lib/vga_isr.s     # VGA interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/crt0.o: lib/crt0.s           # Reset vector
	mkdir -p build
	ca65 $< -o $@

build/irq.o: lib/irq.s             # IRQ and NMI vectors
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

