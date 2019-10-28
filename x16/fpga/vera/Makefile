# This Makefile is used for simulation testing of the VERA module.

SOURCES  = vera.vhd pix.vhd vga.vhd vram.vhd palette.vhd mode0.vhd cpu.vhd
SOURCES += tb.vhd
TB       = tb
WAVE     = tb.ghw
SAVE     = tb.gtkw


#####################################
# Simulation
#####################################

sim: $(SOURCES)
	ghdl -i --std=08 --work=work $(SOURCES)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=12000ns
	gtkwave $(WAVE) $(SAVE)


#####################################
# Cleanup
#####################################

clean:
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf unisim-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)

