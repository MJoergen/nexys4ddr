library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity
-- are mapped directly to pins on the FPGA.

-- In this version the design can generate a checker board
-- pattern on the VGA output.

entity top is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)   -- RRRRGGGGBBB
   );
end top;

architecture structural of top is

   -- Clock divider for VGA
   signal clk_cnt : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk : std_logic;

   -- Test signal
   signal vga_hex : std_logic_vector(255 downto 0);

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   clk_cnt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         clk_cnt <= clk_cnt + 1;
      end if;
   end process clk_cnt_proc;

   vga_clk <= clk_cnt(1);  -- 25 MHz


   --------------------------------------------------
   -- Generate test signal
   --------------------------------------------------

   i_debug : entity work.debug
   port map (
      clk_i => vga_clk,
      hex_o => vga_hex
   ); -- i_debug


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   port map (
      clk_i     => vga_clk,
      hex_i     => vga_hex,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o
   ); -- i_vga

end architecture structural;

