library ieee;
use ieee.std_logic_1164.all;

entity display is
   generic (
      G_FREQ   : integer;
      G_DIGITS : integer := 8;
      G_BITS   : integer
   );
   port (
      -- Clock and reset
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;

      -- Input value
      value_i  : in  std_logic_vector(G_BITS-1 downto 0);

      -- Output segment display
      seg_ca_o : out std_logic_vector(6 downto 0);
      seg_dp_o : out std_logic;
      seg_an_o : out std_logic_vector(G_DIGITS-1 downto 0)
   );
end entity display;

architecture synthesis of display is

   signal segs : std_logic_vector(7*G_DIGITS-1 downto 0);
   signal dp   : std_logic_vector(G_DIGITS-1 downto 0);

begin

   i_display_int2seg : entity work.display_int2seg
      generic map (
         G_DIGITS => G_DIGITS,
         G_BITS   => G_BITS
      )
      port map (
         int_i  => value_i,
         segs_o => segs,
         dp_o   => dp
      ); -- i_display_int2seg


   i_display_seg : entity work.display_seg
      generic map (
         G_FREQ   => G_FREQ,
         G_DIGITS => G_DIGITS
      )
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         segs_i   => segs,
         dp_i     => dp,
         seg_ca_o => seg_ca_o,
         seg_dp_o => seg_dp_o,
         seg_an_o => seg_an_o
      ); -- i_display_seg

end architecture synthesis;
