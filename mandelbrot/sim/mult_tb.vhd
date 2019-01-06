library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library unimacro;
use unimacro.vcomponents.all;

entity mult_tb is
end entity mult_tb;

architecture sim of mult_tb is

   signal clk : std_logic;
   signal rst : std_logic;

   signal a_s : std_logic_vector(17 downto 0);
   signal b_s : std_logic_vector(17 downto 0);
   signal p_s : std_logic_vector(35 downto 0);

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   process
   begin
      wait until rst = '0';
      wait until clk = '1';
      a_s <= "11" & X"FFFF";  -- -0.000015
      b_s <= "11" & X"FFFF";  -- -0.000015
      wait until clk = '1';
      a_s <= "11" & X"FFFF";  -- -0.000015
      b_s <= "00" & X"0001";  --  0.000015
      wait until clk = '1';
      a_s <= "00" & X"0001";  --  0.000015
      b_s <= "00" & X"0001";  --  0.000015
      wait until clk = '1';
      a_s <= "01" & X"FFFF";  --  1.999985
      b_s <= "01" & X"FFFF";  --  1.999985
      wait until clk = '1';
      a_s <= "11" & X"FFFF";  -- -0.000015
      b_s <= "01" & X"FFFF";  --  1.999985
      wait until clk = '1';

      wait until clk = '1';
      wait until clk = '1';

   end process;


   i_mult : mult_macro
   generic map (
      DEVICE  => "7SERIES",
      LATENCY => 1,
      WIDTH_A => 18,
      WIDTH_B => 18
   )
   port map (
      CLK => clk,
      RST => rst,
      CE  => '1',
      P   => p_s,    -- Output
      A   => a_s,    -- Input
      B   => b_s     -- Input
   ); -- i_mult

end architecture sim;

