# This file is specific for the Nexys 4 DDR board.
# See page 7 of the hardware schematic diagram at:
# https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf

# Pin assignment
set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[11] }];    # VGA_R3
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[10] }];    # VGA_R2
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[9]  }];    # VGA_R1
set_property -dict { PACKAGE_PIN A3  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[8]  }];    # VGA_R0
set_property -dict { PACKAGE_PIN A6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[7]  }];    # VGA_G3
set_property -dict { PACKAGE_PIN B6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[6]  }];    # VGA_G2
set_property -dict { PACKAGE_PIN A5  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[5]  }];    # VGA_G1
set_property -dict { PACKAGE_PIN C6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[4]  }];    # VGA_G0
set_property -dict { PACKAGE_PIN D8  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[3]  }];    # VGA_B3
set_property -dict { PACKAGE_PIN D7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[2]  }];    # VGA_B2
set_property -dict { PACKAGE_PIN C7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[1]  }];    # VGA_B1
set_property -dict { PACKAGE_PIN B7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[0]  }];    # VGA_B0
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { vga_hs_o      }];    # VGA_HS
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports { vga_vs_o      }];    # VGA_VS
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk_i         }];    # CLK100MHZ

set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports { eth_mdio_io   }];    # ETH_MDIO
set_property -dict { PACKAGE_PIN C9  IOSTANDARD LVCMOS33 } [get_ports { eth_mdc_o     }];    # ETH_MDC
set_property -dict { PACKAGE_PIN B3  IOSTANDARD LVCMOS33 } [get_ports { eth_rstn_o    }];    # ETH_RSTN
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports { eth_rxd_i[1]  }];    # ETH_RXD[1]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { eth_rxd_i[0]  }];    # ETH_RXD[0]
set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { eth_rxerr_i   }];    # ETH_RXERR
set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { eth_txd_o[0]  }];    # ETH_TXD[0]
set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports { eth_txd_o[1]  }];    # ETH_TXD[1]
set_property -dict { PACKAGE_PIN B9  IOSTANDARD LVCMOS33 } [get_ports { eth_txen_o    }];    # ETH_TXEN
set_property -dict { PACKAGE_PIN D9  IOSTANDARD LVCMOS33 } [get_ports { eth_crsdv_i   }];    # ETH_CRSDV
set_property -dict { PACKAGE_PIN B8  IOSTANDARD LVCMOS33 } [get_ports { eth_intn_i    }];    # ETH_INTN
set_property -dict { PACKAGE_PIN D5  IOSTANDARD LVCMOS33 } [get_ports { eth_refclk_o  }];    # ETH_REFCLK

# Clock definition
create_clock -name sys_clk -period 10.00 [get_ports {clk_i}];                          # 100 MHz
create_generated_clock -name vga_clk -source [get_ports {clk_i}] -divide_by 4 [get_pins {clk_cnt_reg[1]/Q}];   # 25 Mhz
create_generated_clock -name eth_clk -source [get_ports {clk_i}] -divide_by 2 [get_pins {clk_cnt_reg[0]/Q}];   # 50 Mhz

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

