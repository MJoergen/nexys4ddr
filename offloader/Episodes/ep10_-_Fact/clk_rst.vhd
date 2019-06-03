library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

Library xpm;
use xpm.vcomponents.all;

entity clk_rst is
   port (
      sys_clk_i  : in  std_logic;                      -- 100 MHz input clock

      vga_clk_o  : out std_logic;
      vga_rst_o  : out std_logic;
      eth_clk_o  : out std_logic;
      eth_rst_o  : out std_logic;
      math_clk_o : out std_logic;
      math_rst_o : out std_logic
   );
end clk_rst;

architecture structural of clk_rst is

   -- Clock divider for VGA and ETH
   signal sys_clk_cnt : std_logic_vector(1 downto 0) := (others => '0');

   -- Reset counter
   signal sys_rst_cnt : std_logic_vector(20 downto 0) := (others => '1');
   signal sys_rst     : std_logic := '1';

   signal vga_clk     : std_logic;
   signal vga_rst     : std_logic;

   signal eth_clk     : std_logic;
   signal eth_rst     : std_logic;

   signal math_clk    : std_logic;
   signal math_rst    : std_logic;

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   sys_clk_cnt_proc : process (sys_clk_i)
   begin
      if rising_edge(sys_clk_i) then
         sys_clk_cnt <= sys_clk_cnt + 1;
      end if;
   end process sys_clk_cnt_proc;

   vga_clk  <= sys_clk_cnt(1);    -- 25 MHz
   eth_clk  <= sys_clk_cnt(0);    -- 50 MHz
   math_clk <= sys_clk_i;         -- 100 MHz


   --------------------------------------------------
   -- Generate reset.
   -- The reset pulse generated here will have a length of 2^21 cycles at 50
   -- MHz, i.e. 42 ms.
   --------------------------------------------------

   p_sys_rst : process (sys_clk_i)
   begin
      if rising_edge(sys_clk_i) then
         if sys_rst_cnt /= 0 then
            sys_rst_cnt <= sys_rst_cnt - 1;
         else
            sys_rst <= '0';
         end if;

-- pragma synthesis_off
-- This is added to make the reset pulse much shorter during simulation.
         sys_rst_cnt(20 downto 4) <= (others => '0');
-- pragma synthesis_on
      end if;
   end process p_sys_rst;

   i_vga_cdc: xpm_cdc_single
   port map (
      src_clk  => sys_clk_i, -- optional; required when SRC_INPUT_REG = 1
      src_in   => sys_rst,
      dest_clk => vga_clk,
      dest_out => vga_rst
   ); -- i_vga_cdc

   i_eth_cdc: xpm_cdc_single
   port map (
      src_clk  => sys_clk_i, -- optional; required when SRC_INPUT_REG = 1
      src_in   => sys_rst,
      dest_clk => eth_clk,
      dest_out => eth_rst
   ); -- i_eth_cdc

   i_math_cdc: xpm_cdc_single
   port map (
      src_clk  => sys_clk_i, -- optional; required when SRC_INPUT_REG = 1
      src_in   => sys_rst,
      dest_clk => math_clk,
      dest_out => math_rst
   ); -- i_math_cdc


   -- Connect output signals
   vga_clk_o  <= vga_clk;
   vga_rst_o  <= vga_rst;
   eth_clk_o  <= eth_clk;
   eth_rst_o  <= eth_rst;
   math_clk_o <= math_clk;
   math_rst_o <= math_rst;


end architecture structural;

