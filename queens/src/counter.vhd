library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity counter is
   generic (
      G_COUNTER : integer
   );
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      inc_i  : in  std_logic_vector(5 downto 0);
      wrap_o : out std_logic
   );
end entity counter;

architecture synthesis of counter is

   signal count : integer range 0 to G_COUNTER;

begin

   p_count : process (rst_i, clk_i)
   begin
      if rising_edge(clk_i) then
         if count < G_COUNTER then
            count  <= count + conv_integer(inc_i);
            wrap_o <= '0';
         else
            count  <= 0;
            wrap_o <= '1';
         end if;

         if rst_i = '1' then
            count  <= 0;
            wrap_o <= '0';
         end if;
      end if;
   end process p_count;

end architecture synthesis;

