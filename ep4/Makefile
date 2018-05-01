all:
	ghdl -i --work=work cpu_module.vhd ctl.vhd mem.vhd  tb.vhd
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=tb.ghw
