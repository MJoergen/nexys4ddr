library ieee;
use ieee.std_logic_1164.all;

-- Drives the multiplexed 7-segment display, one digit at a time.
-- Digit 0 is the rightmost digit.

entity display_seg is
   generic (
      G_FREQ   : integer;
      G_DIGITS : integer
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      dp_i     : in  std_logic_vector(G_DIGITS-1 downto 0);
      segs_i   : in  std_logic_vector(7*G_DIGITS-1 downto 0);
      seg_ca_o : out std_logic_vector(6 downto 0);
      seg_dp_o : out std_logic;
      seg_an_o : out std_logic_vector(G_DIGITS-1 downto 0)
   );
end entity display_seg;

architecture synthesis of display_seg is

   signal clk_en : std_logic;
   signal digit  : integer range 0 to G_DIGITS-1;

begin

   -- Move to the next digit 1000 times a second.
   i_counter : entity work.counter
   generic map (
      G_COUNTER => G_FREQ/1000
   )
   port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      inc_i  => "000001",
      wrap_o => clk_en
   ); -- i_counter


   count: process (clk_i)
   begin
      if rising_edge(clk_i) then
         if clk_en = '1' then
            if digit = 0 then
               digit <= G_DIGITS-1;
            else
               digit <= digit - 1;
            end if;
         end if;
      end if;
   end process;

   p_out : process (digit, segs_i, dp_i)
   begin
      seg_ca_o <= (others => '1');
      seg_dp_o <= '1';
      seg_an_o <= (others => '1');
      for d in 0 to G_DIGITS-1 loop
         if digit = d then
            seg_ca_o    <= segs_i(7*d+6 downto 7*d);
            seg_dp_o    <= not dp_i(d);
            seg_an_o(d) <= '0';
         end if;
      end loop;
   end process p_out;

end architecture synthesis;
