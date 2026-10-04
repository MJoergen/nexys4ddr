library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

-- This module generates the 108 MHz pixel clock needed for 1280x1024 @ 60 Hz.
--
-- It uses an MMCM (Mixed-Mode Clock Manager), which is a PLL inside the FPGA.
-- The MMCM first multiplies the input frequency, giving the VCO frequency:
-- 100 MHz * 54 / 5 = 1080 MHz. This must be within 600-1200 MHz.
-- Then it divides the VCO frequency down: 1080 MHz / 10 = 108 MHz.

entity clk is
   port (
      clk_i : in  std_logic;   -- 100 MHz
      clk_o : out std_logic    -- 108 MHz
   );
end clk;

architecture structural of clk is

   signal clkfb_s : std_logic;
   signal clk_s   : std_logic;

begin

   i_mmcm : MMCME2_BASE
      generic map (
         CLKIN1_PERIOD    => 10.0,     -- 100 MHz
         DIVCLK_DIVIDE    => 5,
         CLKFBOUT_MULT_F  => 54.0,     -- VCO = 1080 MHz
         CLKOUT0_DIVIDE_F => 10.0      -- 108 MHz
      )
      port map (
         CLKIN1   => clk_i,
         CLKFBIN  => clkfb_s,
         CLKFBOUT => clkfb_s,
         CLKOUT0  => clk_s,
         PWRDWN   => '0',
         RST      => '0'
      ); -- i_mmcm

   -- Use a global clock buffer, to distribute the clock to the entire FPGA.
   i_bufg : BUFG
      port map (
         I => clk_s,
         O => clk_o
      ); -- i_bufg

end architecture structural;
