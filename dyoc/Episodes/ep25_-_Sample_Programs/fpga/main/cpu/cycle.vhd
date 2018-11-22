library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity cycle is
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;

      latch_i   : in  std_logic;
      cyc_cnt_o : out std_logic_vector(31 downto 0)
   );
end entity cycle;

architecture structural of cycle is

   signal cyc_cnt   : std_logic_vector(31 downto 0);
   signal cyc_latch : std_logic_vector(31 downto 0);

begin

   -----------------
   -- Statistics
   -----------------

   -- Cycle counter
   p_cyc_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         cyc_cnt <= cyc_cnt + 1;

         if rst_i = '1' then
            cyc_cnt <= (others => '0');
         end if;
      end if;
   end process p_cyc_cnt;

   -- Latch cycle counter when reading
   p_cyc_latch : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if latch_i = '0' then
            cyc_latch <= cyc_cnt;
         end if;
      end if;
   end process p_cyc_latch;


   -----------------------
   -- Drive Output Signals
   -----------------------

   cyc_cnt_o <= cyc_latch;

end architecture structural;

