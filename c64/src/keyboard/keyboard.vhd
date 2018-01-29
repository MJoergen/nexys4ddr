library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity keyboard is
   port (
      -- Clock
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      rden_i     : in  std_logic;
      val_o      : out std_logic_vector(7 downto 0);
      debug_o    : out std_logic_vector(69 downto 0)
   );
end keyboard;

architecture Structural of keyboard is

   signal key   : std_logic_vector(7 downto 0);
   signal valid : std_logic;

begin

   ------------------
   -- Instantiate PS2
   ------------------
   inst_ps2 : entity work.ps2
   port map (
      clk_i      => clk_i,
      rst_i      => rst_i,

      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      key_o      => key,
      valid_o    => valid
   );

   inst_bytefifo : entity work.bytefifo
   generic map (
      SIZE => 8
   )
   port map (
      -- Clock
      clk_i  => clk_i,
      rst_i  => rst_i,

      wren_i => valid,
      val_i  => key,

      rden_i => rden_i,
      val_o  => val_o,

      debug_o => debug_o
   );

end Structural;

