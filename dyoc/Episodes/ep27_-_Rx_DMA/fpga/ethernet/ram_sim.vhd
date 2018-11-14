library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

-- This module is part of the test bench for the Ethernet module.

entity ram_sim is
   port (
      clk_i      : in  std_logic;
      wr_en_i    : in  std_logic;
      wr_addr_i  : in  std_logic_vector(15 downto 0);
      wr_data_i  : in  std_logic_vector( 7 downto 0);
      ram_in_i   : in  std_logic_vector(16383 downto 0);
      ram_out_o  : out std_logic_vector(16383 downto 0);
      ram_init_i : in  std_logic
   );
end entity ram_sim;

architecture simulation of ram_sim is

   -- Initialize memory contents
   signal ram : std_logic_vector(16383 downto 0);

begin

   proc_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            assert wr_addr_i(15 downto 11) = "00100";
            ram(to_integer(wr_addr_i(10 downto 0))*8+7 downto to_integer(wr_addr_i(10 downto 0))*8) <= wr_data_i;
         end if;

         if ram_init_i = '1' then
            ram <= ram_in_i;
         end if;
      end if;
   end process proc_write;

   -- Connect output signals
   ram_out_o <= ram;

end simulation;

