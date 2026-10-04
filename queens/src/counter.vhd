library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

   -- The counter can go up to 63 past G_COUNTER before it wraps.
   signal count : integer range 0 to G_COUNTER + 63;

begin

   p_count : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if count < G_COUNTER then
            count  <= count + to_integer(unsigned(inc_i));
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
