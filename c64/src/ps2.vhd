--------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ps2 is
   port (
      -- Clock
      sys_clk_i  : in  std_logic;

      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      key_o      : out std_logic_vector(31 downto 0)
   );
end ps2;

architecture Structural of ps2 is

   signal data_cur  : std_logic_vector(7 downto 0);
   signal data_prev : std_logic_vector(7 downto 0);
   signal cnt       : integer range 0 to 10 := 0;
   signal flag      : std_logic := '0';

   signal key       : std_logic_vector(31 downto 0) := (others => '0');

begin

   process (ps2_clk_i)
   begin
      if falling_edge(ps2_clk_i) then
         case cnt is
            when  0 => null;
            when  1 => data_cur(0) <= ps2_data_i;
            when  2 => data_cur(1) <= ps2_data_i;
            when  3 => data_cur(2) <= ps2_data_i;
            when  4 => data_cur(3) <= ps2_data_i;
            when  5 => data_cur(4) <= ps2_data_i;
            when  6 => data_cur(5) <= ps2_data_i;
            when  7 => data_cur(6) <= ps2_data_i;
            when  8 => data_cur(7) <= ps2_data_i;
            when  9 => flag <= '1';
            when 10 => flag <= '0';
         end case;

         if cnt <= 9 then
            cnt <= cnt + 1;
         else
            cnt <= 0;
         end if;
      end if;
   end process;

   process (flag)
   begin
      if rising_edge(flag) then
         if data_prev /= data_cur then
            key(31 downto 24) <= key(23 downto 16);
            key(23 downto 16) <= key(15 downto  8);
            key(15 downto  8) <= data_prev;
            key( 7 downto  0) <= data_cur;
            data_prev <= data_cur;
         end if;
      end if;
   end process;

   key_o <= key;

end Structural;

