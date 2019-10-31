# This Makefile is used for simulation testing of the VERA module.
# Simulation is done using the program ghdl. It may be available
# in your OS repository, otherwise it may be downloaded from here:
# https://github.com/ghdl/ghdl

SOURCES  = vera.vhd vram.vhd palette.vhd cdc.vhd                  # Mixed clock domain
SOURCES += cpu/mmu.vhd cpu/config.vhd cpu/cpu.vhd                 # All CPU clock domain
SOURCES += vga/pix.vhd vga/sync.vhd vga/vga.vhd vga/layer.vhd     # All VGA clock domain
SOURCES += test/tb.vhd ../cpu_dummy.vhd
TB       = tb
WAVE     = test/tb.ghw
SAVE     = test/tb.gtkw


#####################################
# Simulation
#####################################

sim: $(SOURCES)
	ghdl -i --std=08 --work=work $(SOURCES)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=42000ns
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

