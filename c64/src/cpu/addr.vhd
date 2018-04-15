--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity addr is
   port (
      -- Clock
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;

      wr_i   : in  std_logic_vector(1 downto 0);
      data_i : in  std_logic_vector(7 downto 0);
      regs_i : in  std_logic_vector(7 downto 0);

      addr_o : out std_logic_vector(15 downto 0)
   );
end addr;

architecture Structural of addr is

   signal addr_r : std_logic_vector(15 downto 0);

begin


   -- Memory address hold register
   p_addr_r : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case wr_i is
            when "01" => addr_r( 7 downto 0) <= data_i;           -- Used during zero-page addressing mode
                         addr_r(15 downto 8) <= (others => '0');
            when "10" => addr_r(15 downto 8) <= data_i;           -- Used during absolute addressing modes
            when "11" => addr_r <= addr_r + regs_i;   -- Used during indirect addressing
            when others => null;
         end case;
      end if;
   end process p_addr_r;


   -----------------------
   -- Drive output signals
   -----------------------

   addr_o <= addr_r;

end Structural;

