library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

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

   signal clk_step     : std_logic;
   signal clk_mode     : std_logic;
   signal clk_mode_inv : std_logic;

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


   clk_mode_inv <= not clk_mode;

   -----------------------
   -- Drive output signals
   -----------------------

--   clk_o <= clk_i when clk_mode = '0' else clk_step;

   -- Note: For some reason, synthesis fails if I0 and I1 are swapped.
   inst_bufgmux : BUFGCTRL
   port map (
      IGNORE0 => '0',
      IGNORE1 => '0',
      S0      => '1',
      S1      => '1',
      I1      => clk_i,
      I0      => clk_step,
      CE0     => clk_mode,
      CE1     => clk_mode_inv,
      O       => clk_o
   );

end architecture Structural;

