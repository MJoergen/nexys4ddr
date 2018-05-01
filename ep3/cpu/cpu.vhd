--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity cpu is
   port (
      -- Clock
      clk_i     : in  std_logic;
      ce_i      : in  std_logic; -- Clock Enable

      -- Memory and I/O interface
      addr_o    : out std_logic_vector(15 downto 0);
      data_i    : in  std_logic_vector(7 downto 0);
      wren_o    : out std_logic;
      data_o    : out std_logic_vector(7 downto 0)
   );
end cpu;

architecture Structural of cpu is

   signal pc_reg : std_logic_vector(15 downto 0) := (others => '0');

begin

   -----------------------
   -- Program counter
   -----------------------

   p_pc_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ce_i = '1' then
            pc_reg <= pc_reg + 1;
         end if;
      end if;
   end process p_pc_reg;


   -----------------------
   -- Drive output signals
   -----------------------

   addr_o <= pc_reg;
   data_o <= (others => '0');
   wren_o <= '0';

end Structural;

