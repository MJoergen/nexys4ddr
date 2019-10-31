library ieee;
use ieee.std_logic_1164.all;

-- This block is a simple synchronizer, used for Clock Domain Crossing.
--
-- Note: There is no parallel synchronization, so the individual bits in the
-- input may not be synchronized at the same time. If you require the input
-- vector to be synchronized in parallel, i.e. simultaneously, you should use a
-- FIFO.

entity cdc is
   generic (
      G_SIZE : integer
   );
   port (
      src_clk_i : in  std_logic;
      src_dat_i : in  std_logic_vector(G_SIZE-1 downto 0);
      dst_clk_i : in  std_logic;
      dst_dat_o : out std_logic_vector(G_SIZE-1 downto 0)
   );
end cdc;

architecture structural of cdc is

   signal dst_dat_r : std_logic_vector(G_SIZE-1 downto 0);
   signal dst_dat_d : std_logic_vector(G_SIZE-1 downto 0);

   attribute ASYNC_REG              : string;
   attribute ASYNC_REG of dst_dat_r : signal is "TRUE";
   attribute ASYNC_REG of dst_dat_d : signal is "TRUE";   

begin

   gen_cdc : if true generate
      p_sync : process (dst_clk_i)
      begin
         if rising_edge(dst_clk_i) then
            dst_dat_r <= src_dat_i;
            dst_dat_d <= dst_dat_r;
         end if;
      end process p_sync;

      dst_dat_o <= dst_dat_d;
   end generate gen_cdc;

end architecture structural;

