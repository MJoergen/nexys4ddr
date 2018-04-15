--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sp is
   port (
      -- Clock
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;

      wr_i   : in  std_logic_vector(1 downto 0);
      regs_i : in  std_logic_vector(7 downto 0);

      sp_o   : out std_logic_vector(7 downto 0)
   );
end sp;

architecture Structural of sp is

   signal sp_r : std_logic_vector( 7 downto 0);

begin

   -- Stack pointer
   p_sp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case wr_i is
            when "01" => sp_r <= regs_i;
            when "10" => sp_r <= sp_r - 1;
            when "11" => sp_r <= sp_r + 1;
            when others => null;
         end case;

         if rst_i = '1' then
            sp_r <= X"FF";
         end if;
      end if;
   end process p_sp;

   -----------------------
   -- Drive output signals
   -----------------------

   sp_o <= sp_r;

end Structural;

