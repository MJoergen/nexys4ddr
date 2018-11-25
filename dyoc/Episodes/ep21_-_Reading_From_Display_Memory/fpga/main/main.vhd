library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the MAIN module. This contains the memory and the CPU.

entity main is
   generic (
      G_ROM_INIT_FILE : string;
      G_OVERLAY_BITS  : integer
   );
   port (
      main_clk_i      : in  std_logic;
      main_rst_i      : in  std_logic;
      main_wait_i     : in  std_logic;
      main_led_o      : out std_logic_vector(7 downto 0);
      main_overlay_o  : out std_logic_vector(G_OVERLAY_BITS-1 downto 0);
      --
      vga_clk_i       : in  std_logic;
      vga_char_addr_i : in  std_logic_vector(12 downto 0);
      vga_char_data_o : out std_logic_vector( 7 downto 0);
      vga_col_addr_i  : in  std_logic_vector(12 downto 0);
      vga_col_data_o  : out std_logic_vector( 7 downto 0)
   );
end main;

architecture structural of main is

   -- Data Path signals
   signal main_cpu_addr : std_logic_vector(15 downto 0);
   signal main_mem_data : std_logic_vector(7 downto 0);
   signal main_cpu_rden : std_logic;
   signal main_cpu_data : std_logic_vector(7 downto 0);
   signal main_cpu_wren : std_logic;
   signal main_cpu_wait : std_logic;
   signal main_mem_wait : std_logic;

begin
   
   main_cpu_wait <= main_wait_i or main_mem_wait;

   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   cpu_inst : entity work.cpu
   generic map (
      G_OVERLAY_BITS => G_OVERLAY_BITS 
   )
   port map (
      clk_i     => main_clk_i,
      rst_i     => main_rst_i,
      nmi_i     => '0',
      irq_i     => '0',
      wait_i    => main_cpu_wait,
      addr_o    => main_cpu_addr,
      data_i    => main_mem_data,
      wren_o    => main_cpu_wren,
      rden_o    => main_cpu_rden,
      data_o    => main_cpu_data,
      invalid_o => main_led_o,
      overlay_o => main_overlay_o
   ); -- cpu_inst


   --------------------------------------------------
   -- Instantiate Memory module
   --------------------------------------------------
   
   mem_inst : entity work.mem
   generic map (
      G_ROM_SIZE  => 14, -- 16 Kbytes
      G_RAM_SIZE  => 15, -- 32 Kbytes
      G_CHAR_SIZE => 13, -- 8 Kbytes
      G_COL_SIZE  => 13, -- 8 Kbytes
      --
      G_ROM_MASK  => X"C000",
      G_RAM_MASK  => X"0000",
      G_CHAR_MASK => X"8000",
      G_COL_MASK  => X"A000",
      --
      G_ROM_FILE  => G_ROM_INIT_FILE
   )
   port map (
      a_clk_i       => main_clk_i,
      a_addr_i      => main_cpu_addr,
      a_rden_i      => main_cpu_rden,
      a_data_o      => main_mem_data,
      a_wren_i      => main_cpu_wren,
      a_data_i      => main_cpu_data,
      a_wait_o      => main_mem_wait,
      --
      b_clk_i       => vga_clk_i,
      b_char_addr_i => vga_char_addr_i,
      b_char_data_o => vga_char_data_o,
      b_col_addr_i  => vga_col_addr_i,
      b_col_data_o  => vga_col_data_o
   ); -- mem_inst

end architecture structural;

