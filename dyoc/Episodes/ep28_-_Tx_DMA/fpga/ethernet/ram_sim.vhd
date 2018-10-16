library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

-- This module is part of the test bench for the Ethernet module.

entity ram_sim is
   port (
      clk_i   : in  std_logic;
      wren_i  : in  std_logic;
      addr_i  : in  std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector( 7 downto 0);
      ram_o   : out std_logic_vector(16383 downto 0);
      clear_i : in  std_logic
   );
end entity ram_sim;

architecture simulation of ram_sim is

   -- Initialize memory contents
   signal ram : std_logic_vector(16383 downto 0);

begin

   proc_ram : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            assert addr_i(15 downto 11) = "00100";
            ram(conv_integer(addr_i(10 downto 0))*8+7 downto conv_integer(addr_i(10 downto 0))*8) <= data_i;
         end if;

         if clear_i = '1' then
            ram <= (others => 'X');
         end if;
      end if;
   end process proc_ram;

   -- Connect output signals
   ram_o <= ram;

end simulation;

