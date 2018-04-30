all:
	ghdl -i --work=work --std=08 alu.vhd tb_alu.vhd
	ghdl -m --std=08 tb_alu
	ghdl -r tb_alu --assert-level=error --wave=tb_alu.ghw
