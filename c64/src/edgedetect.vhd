library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module converts an incoming broad pulse into a single clock pulse

entity edgedetect is

   port (
           clk_i : in  std_logic;
           sig_i : in  std_logic;
           sig_o : out std_logic
        );

end entity edgedetect;

architecture Structural of edgedetect is

   signal sig_d_s   : std_logic := '0';
   signal sig_out_s : std_logic := '0';

begin

   p_sig_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         sig_d_s <= sig_i;
      end if;
   end process p_sig_d;


   p_sig_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         sig_out_s <= '0';
         if sig_d_s = '0' and sig_i = '1' then
            sig_out_s <= '1';
         end if;
      end if;
   end process p_sig_out;

   sig_o <= sig_out_s;

end architecture Structural;

