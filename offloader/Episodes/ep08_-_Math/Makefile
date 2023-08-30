XILINX_DIR = /opt/Xilinx/Vivado/2021.2

SRCS  = top.vhd cdc.vhd clk_rst.vhd wide_fifo.vhd
SRCS += eth/fifo.vhd eth/strip_crc.vhd eth/byte2wide.vhd eth/wide2byte.vhd
SRCS += eth/eth_rx.vhd eth/eth_tx.vhd eth/eth.vhd
SRCS += eth/eth_types.vhd eth/arp.vhd eth/icmp.vhd eth/udp.vhd
SRCS += math/math.vhd math/sqrt.vhd
SRCS += vga/vga.vhd vga/pix.vhd vga/rom.vhd 

top.bit: top.xpr $(SRCS) top.xdc Makefile
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado $<"

fpga: top.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf top.cache
	rm -rf top.hw
	rm -rf top.runs
	rm -rf .Xil
	rm -rf .cache

