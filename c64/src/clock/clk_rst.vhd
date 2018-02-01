library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module generates the clock and reset signals.

entity clk_rst is

   port (
           clk_i  : in  std_logic;
           mode_i : in  std_logic;
           step_i : in  std_logic;
           clk_o  : out std_logic
        );

end entity clk_rst;

architecture Structural of clk_rst is

   signal clk_step : std_logic;
   signal clk_mode : std_logic;

begin

   ------------------------------
   -- Instantiate Debounce
   ------------------------------

   inst_step_debounce : entity work.debounce
   port map (
      clk_i => clk_i,

      in_i  => step_i,
      out_o => clk_step
   );

   inst_mode_debounce : entity work.debounce
   port map (
      clk_i => clk_i,

      in_i  => mode_i,
      out_o => clk_mode
   );


   -----------------------
   -- Drive output signals
   -----------------------

   clk_o <= clk_i when clk_mode = '0' else clk_step;

end architecture Structural;

