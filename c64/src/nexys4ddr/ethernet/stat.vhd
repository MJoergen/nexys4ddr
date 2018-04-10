library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity stat is

   generic (
      G_NUM : integer
   );
   port (
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      inc_i   : in  std_logic_vector(G_NUM-1 downto 0);
      clks_i  : in  std_logic_vector(G_NUM-1 downto 0);
      rsts_i  : in  std_logic_vector(G_NUM-1 downto 0);
      addr_i  : in  std_logic_vector( 7 downto 0);
      data_o  : out std_logic_vector(15 downto 0);
      debug_o : out std_logic_vector(16*G_NUM-1 downto 0)
   );
end stat;

architecture Structural of stat is

   type t_stats is array (0 to G_NUM-1) of std_logic_vector(15 downto 0);

   signal i_stats : t_stats;

begin

   gen_debug : for i in 0 to G_NUM-1 generate
      debug_o(16*i+15 downto 16*i) <= i_stats(i);
   end generate gen_debug;

   gen_count : for i in 0 to G_NUM-1 generate
      proc_count : process (clks_i(i))
      begin
         if rising_edge(clks_i(i)) then
            if inc_i(i) = '1' then
               i_stats(i) <= i_stats(i) + 1;
            end if;

            if rsts_i(i) = '1' then
               i_stats(i) <= (others => '0');
            end if;
         end if;
      end process proc_count;
   end generate gen_count;


   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if addr_i < G_NUM then
            data_o <= i_stats(conv_integer(addr_i));
         end if;
      end if;
   end process proc_read;

end Structural;

