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

build/comp.lib: build/crt0.o build/vga.o build/clock.o build/timer_isr.o build/sys_irq.o build/irq.o build/kbd_isr.o \
                build/kbd.o build/vga_isr.o build/putchar.o build/scrsize.o build/cursor.o
	cp lib/none.lib $@
	ar65 r $@ $^

build/vga_isr.o: lib/vga_isr.s     # VGA interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/kbd_isr.o: lib/kbd_isr.s     # Keyboard interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/clock.o: lib/clock.s
	mkdir -p build
	ca65 $< -o $@

build/timer_isr.o: lib/timer_isr.s # Timer interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/cursor.o: build/cursor.s   # 
	ca65 $< -o $@

build/cursor.s: lib/cursor.c     # 
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/scrsize.o: build/scrsize.s   # 
	ca65 $< -o $@

build/scrsize.s: lib/scrsize.c     # 
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/putchar.o: build/putchar.s   # 
	ca65 $< -o $@

build/putchar.s: lib/putchar.c     # 
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/vga.o: build/vga.s   # IRQ and NMI vectors
	ca65 $< -o $@

build/vga.s: lib/vga.c     # IRQ and NMI vectors
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/kbd.o: build/kbd.s   # IRQ and NMI vectors
	ca65 $< -o $@

build/kbd.s: lib/kbd.c     # IRQ and NMI vectors
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/sys_irq.o: build/sys_irq.s   # IRQ and NMI vectors
	ca65 $< -o $@

build/sys_irq.s: lib/sys_irq.c     # IRQ and NMI vectors
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/irq.o: lib/irq.s             # IRQ and NMI vectors
	mkdir -p build
	ca65 $< -o $@

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
