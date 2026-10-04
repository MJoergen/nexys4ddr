library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity clk is
   port
   (
      clk_i : in  std_logic;   -- 100 MHz
      rst_i : in  std_logic;   -- Asynchronous, resets the PLL
      clk_o : out std_logic;   -- 25 MHz
      rst_o : out std_logic    -- Synchronous to clk_o
   );
end entity clk;

architecture synthesis of clk is

  signal clkfbout : std_logic;
  signal clk_out0 : std_logic;
  signal clk_bufg : std_logic;
  signal locked   : std_logic;

  -- Shift register that holds the reset until a few clock cycles after the
  -- PLL has locked.
  signal rst_sr   : std_logic_vector(3 downto 0) := (others => '1');

begin

   -- 100 MHz * 50 / 5 / 40 = 25 MHz
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
         LOCKED   => locked,
         PWRDWN   => '0',
         RST      => rst_i
      ); -- i_plle2_adv

   i_bufg : BUFG
      port map
      (
         I => clk_out0,
         O => clk_bufg
      ); -- i_bufg

   clk_o <= clk_bufg;

   -- The reset is asserted asynchronously while the PLL is not locked, and
   -- released synchronously to clk_bufg.
   p_rst : process (clk_bufg, locked)
   begin
      if locked = '0' then
         rst_sr <= (others => '1');
      elsif rising_edge(clk_bufg) then
         rst_sr <= rst_sr(rst_sr'left-1 downto 0) & '0';
      end if;
   end process p_rst;

   rst_o <= rst_sr(rst_sr'left);

end architecture synthesis;

