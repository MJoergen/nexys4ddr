library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clk is
   port
   (
      clk_i : in  std_logic;
      clk_o : out std_logic
   );
end entity clk;

architecture synthesis of clk is

  signal clkfbout : std_logic;
  signal clk_out0 : std_logic;

begin

   -- Instantiation of the MMCM PRIMITIVE
   i_plle2_adv : PLLE2_ADV
      generic map
      (
         COMPENSATION   => "INTERNAL",
         CLKOUT0_DIVIDE => 40,
         CLKFBOUT_MULT  => 50,
         DIVCLK_DIVIDE  => 5,
         REF_JITTER1    => 0.010,
         CLKIN1_PERIOD  => 10.0
      )
      port map
      (
         CLKFBOUT => clkfbout,
         CLKOUT0  => clk_out0,
         CLKOUT1  => open,
         CLKOUT2  => open,
         CLKOUT3  => open,
         CLKOUT4  => open,
         CLKOUT5  => open,
         CLKFBIN  => clkfbout,
         CLKIN1   => clk_i,
         CLKIN2   => '0',
         CLKINSEL => '1',
         DADDR    => (others => '0'),
         DCLK     => '0',
         DEN      => '0',
         DI       => (others => '0'),
         DO       => open,
         DRDY     => open,
         DWE      => '0',
         LOCKED   => open,
         PWRDWN   => '0',
         RST      => '0'
      ); -- i_plle2_adv

   i_bufg : BUFG
      port map
      (
         I => clk_out0,
         O => clk_o
      ); -- i_bufg

end architecture synthesis;

