library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tb is
end tb;

architecture Structural of tb is

   -- Clock
   signal clk  : std_logic;

   -- Data Path signals
   signal cpu_addr  : std_logic_vector(15 downto 0);
   signal mem_data  : std_logic_vector(7 downto 0);
   signal cpu_data  : std_logic_vector(7 downto 0);
   signal cpu_wren  : std_logic;

   -- Debug output
   signal cpu_led   : std_logic_vector(7 downto 0);
   signal cpu_debug : std_logic_vector(159 downto 0);

begin
   
   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   -- Generate clock
   clk_gen : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process clk_gen;

   
   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   i_cpu : entity work.cpu
   port map (
      clk_i     => clk,
      wait_i    => '0',
      addr_o    => cpu_addr,
      data_i    => mem_data,
      wren_o    => cpu_wren,
      data_o    => cpu_data,
      invalid_o => cpu_led,
      debug_o   => cpu_debug
   );

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   port map (
      clk_i  => clk,
      addr_i => cpu_addr,  -- Only select the relevant address bits
      data_o => mem_data,
      wren_i => cpu_wren,
      data_i => cpu_data
   );

end architecture Structural;

