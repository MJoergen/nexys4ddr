# Include directory
INCLUDE = inc


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

build/comp.lib: build/crt0.o build/write.o build/clrscr.o build/clock.o build/timer_isr.o \
                build/sys_irq.o build/irq.o build/kbd_isr.o build/cgetc.o build/read.o build/screensize.o build/kbhit.o
	cp lib/none.lib $@
	ar65 r $@ $^

build/kbhit.o: lib/kbhit.s
	mkdir -p build
	ca65 $< -o $@

build/screensize.o: lib/screensize.s
	mkdir -p build
	ca65 $< -o $@

build/cgetc.o: build/cgetc.s
	ca65 $< -o $@

build/cgetc.s: lib/cgetc.c
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/kbd_isr.o: lib/kbd_isr.s     # Keyboard interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/clock.o: lib/clock.s
	ca65 $< -o $@

build/timer_isr.o: lib/timer_isr.s # Timer interrupt service routine
	mkdir -p build
	ca65 $< -o $@

build/sys_irq.o: build/sys_irq.s   # IRQ and NMI vectors
	ca65 $< -o $@

build/sys_irq.s: lib/sys_irq.c     # IRQ and NMI vectors
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/irq.o: lib/irq.s             # IRQ and NMI vectors
	mkdir -p build
	ca65 $< -o $@

build/read.o: build/read.s
	ca65 $< -o $@

build/read.s: lib/read.c
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/write.o: build/write.s
	ca65 $< -o $@

build/write.s: lib/write.c
	mkdir -p build
	cc65 -I $(INCLUDE) -g -t none -O $< -o $@

build/clrscr.o: lib/clrscr.s       # Clear screen
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
