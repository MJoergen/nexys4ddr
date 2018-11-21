library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module models a simple Chip Interrupt Controller.
-- There is a single 1-byte register.
-- Bit 0 : IRQ
-- Bit 1 : NMI
-- Both bits are level sensitive.

entity cic is
   port (
      clk_i  : in  std_logic;

      -- Data contents at the selected address.
      -- Valid in same clock cycle.
      data_o : out std_logic_vector(7 downto 0);

      -- New data to (optionally) be written to the selected address.
      data_i : in  std_logic_vector(7 downto 0);

      -- '1' indicates we wish to perform a write at the selected address.
      wren_i : in  std_logic;

      stat_o : out std_logic_vector(7 downto 0)
   );
end cic;

architecture structural of cic is

   signal stat : std_logic_vector(7 downto 0) := X"00";

begin

   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            stat <= data_i;
         end if;
      end if;
   end process p_write;

   p_read : process (clk_i)
   begin
      if falling_edge(clk_i) then
         data_o <= stat;
      end if;
   end process p_read;

   stat_o <= stat;

end structural;

