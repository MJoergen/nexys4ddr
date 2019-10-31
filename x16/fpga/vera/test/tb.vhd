library ieee;
use ieee.std_logic_1164.all;

-- This is a test bench for the VERA

entity tb is
end tb;

architecture simulation of tb is

   signal cpu_clk_s     : std_logic;                       -- 8.3 MHz
   signal cpu_addr_s    : std_logic_vector(2 downto 0);
   signal cpu_wr_en_s   : std_logic;
   signal cpu_wr_data_s : std_logic_vector(7 downto 0);
   signal cpu_rd_en_s   : std_logic;
   signal cpu_rd_data_s : std_logic_vector(7 downto 0);

   signal vga_clk_s     : std_logic;                       -- 25 MHz
   signal vga_hs_s      : std_logic; 
   signal vga_vs_s      : std_logic;
   signal vga_col_s     : std_logic_vector(11 downto 0);   -- 4 bits for each colour RGB.

begin

   --------------------
   -- Clock generation
   --------------------

   p_cpu_clk : process
   begin
      cpu_clk_s <= '1', '0' after 3*2 ns;
      wait for 3*4 ns; -- 8.3 MHz
   end process p_cpu_clk;

   p_vga_clk : process
   begin
      vga_clk_s <= '1', '0' after 2 ns;
      wait for 4 ns; -- 25 MHz
   end process p_vga_clk;


   -------------------------
   -- Instantiate dummy CPU
   -------------------------

   i_cpu_dummy : entity work.cpu_dummy
      port map (
         clk_i     => cpu_clk_s,
         addr_o    => cpu_addr_s,
         wr_en_o   => cpu_wr_en_s,
         wr_data_o => cpu_wr_data_s,
         rd_en_o   => cpu_rd_en_s,
         rd_data_i => cpu_rd_data_s
      ); -- i_cpu_dummy


   --------------------
   -- Instantiate VERA
   --------------------

   i_vera : entity work.vera
      port map (
         cpu_clk_i     => cpu_clk_s,
         cpu_addr_i    => cpu_addr_s,
         cpu_wr_en_i   => cpu_wr_en_s,
         cpu_wr_data_i => cpu_wr_data_s,
         cpu_rd_en_i   => cpu_rd_en_s,
         cpu_rd_data_o => cpu_rd_data_s,
         vga_clk_i     => vga_clk_s,
         vga_hs_o      => vga_hs_s,
         vga_vs_o      => vga_vs_s,
         vga_col_o     => vga_col_s
      ); -- i_vera

end architecture simulation;

