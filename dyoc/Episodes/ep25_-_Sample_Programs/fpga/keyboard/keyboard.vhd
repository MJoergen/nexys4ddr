library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity keyboard is
   port (
      clk_i      : in std_logic;

      -- From keyboard
      ps2_clk_i  : in std_logic;
      ps2_data_i : in std_logic;

      -- To computer
      data_o     : out std_logic_vector(7 downto 0);
      irq_o      : out std_logic;

      debug_o    : out std_logic_vector(15 downto 0)
   );
end entity keyboard;

architecture structural of keyboard is

   signal ps2_valid : std_logic;
   signal ps2_data  : std_logic_vector(7 downto 0);

   signal valid     : std_logic;
   signal ascii     : std_logic_vector(7 downto 0);

begin

   inst_ps2 : entity work.ps2
   port map (
      clk_i      => clk_i,
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      data_o     => ps2_data,
      valid_o    => ps2_valid
   );

   inst_scancode : entity work.scancode
   port map (
      clk_i      => clk_i,
      keycode_i  => ps2_data,
      valid_i    => ps2_valid,
      ascii_o    => ascii,
      valid_o    => valid
   );

   debug_o( 7 downto 0) <= ps2_data;
   debug_o(15 downto 8) <= ascii;

   data_o <= ascii;
   irq_o  <= valid;

end architecture structural;

