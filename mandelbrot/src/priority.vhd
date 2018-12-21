library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a simple priority encoder.
-- There is room for improvement, in case the input vector is very large.

entity priority is
   generic (
      G_SIZE      : integer
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      vector_i  : in  std_logic_vector(G_SIZE-1 downto 0);
      index_o   : out integer range 0 to G_SIZE-1;
      active_o  : out std_logic
   );
end entity priority;

architecture rtl of priority is

   signal index_r  : integer range 0 to G_SIZE-1;
   signal active_r : std_logic;

begin

   p_res : process (clk_i)
   begin
      if rising_edge(clk_i) then

         active_r <= '0';

         idx_start_loop : for i in 0 to G_SIZE-1 loop
            if vector_i(i) = '1' then
               index_r  <= i;
               active_r <= '1';
               exit idx_start_loop;
            end if;
         end loop idx_start_loop;

      end if;
   end process p_res;

   active_o <= active_r;
   index_o  <= index_r;

end architecture rtl;

