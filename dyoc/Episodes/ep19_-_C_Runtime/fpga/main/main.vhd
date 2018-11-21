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
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      wait_i    : in  std_logic;
      led_o     : out std_logic_vector(7 downto 0);
      overlay_o : out std_logic_vector(G_OVERLAY_BITS-1 downto 0)
   );
end main;

architecture structural of main is

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_wren  : std_logic;

begin
   
   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   cpu_inst : entity work.cpu
   generic map (
      G_OVERLAY_BITS => G_OVERLAY_BITS 
   )
   port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      nmi_i     => '0',
      irq_i     => '0',
      wait_i    => wait_i,
      addr_o    => cpu_addr,
      data_i    => mem_data,
      wren_o    => cpu_wren,
      data_o    => cpu_data,
      invalid_o => led_o,
      overlay_o => overlay_o
   ); -- cpu_inst


   --------------------------------------------------
   -- Instantiate Memory module
   --------------------------------------------------
   
   mem_inst : entity work.mem
   generic map (
      G_ROM_INIT_FILE => G_ROM_INIT_FILE
   )
   port map (
      clk_i  => clk_i,
      addr_i => cpu_addr,
      data_o => mem_data,
      wren_i => cpu_wren,
      data_i => cpu_data
   ); -- mem_inst

end architecture structural;

