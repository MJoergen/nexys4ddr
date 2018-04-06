library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module contains all the memory and memory-mapped IO accessible by the
-- CPU.
-- Port A is connected to the CPU (and the Ethernet module).  Some memory (RAM
-- and ROM and CONF) have zero latency, i.e. value is ready upon next clock
-- cycle.  Other memory (DISP and FONT and MOB) have a one cycle read delay on
-- port A, where a_wait_o is asserted. This is because the VGA module needs to
-- read this memory, and hence uses an additional read port of the BRAM.
-- Port B is connected to the GPU. No address decoding is done, because reads
-- occur simultaneously, the DISP and FONT and MOB memories must all be
-- readable on the same clock cycle.

entity conf_mem is

   generic (
      G_CONF_SIZE : integer           -- Number of bits in CONF address
   );
   port (
      a_clk_i     : in  std_logic;
      a_rst_i     : in  std_logic;
      a_addr_i    : in  std_logic_vector(15 downto 0);
      a_data_i    : in  std_logic_vector(7 downto 0);
      a_wr_en_i   : in  std_logic;
      a_rd_en_i   : in  std_logic;
      a_rd_data_o : out std_logic_vector(7 downto 0);
      --
      b_clk_i     : in  std_logic;
      b_rst_i     : in  std_logic;
      b_config_o  : out std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0)
  );
end conf_mem;

architecture Structural of conf_mem is

   signal config : std_logic_vector(2**(G_CONF_SIZE+3)-1 downto 0);

begin

   --------------
   -- Port A
   --------------

   conf_a_proc : process (a_clk_i)
      variable addr_v : integer range 0 to 2**G_CONF_SIZE-1;
   begin
      if rising_edge(a_clk_i) then
         addr_v := conv_integer(a_addr_i(G_CONF_SIZE-1 downto 0));
         if a_wr_en_i = '1' then
            config(addr_v*8+7 downto addr_v*8) <= a_data_i;
         end if;
         if a_rd_en_i = '1' then
            a_rd_data_o <= config(addr_v*8+7 downto addr_v*8);
         end if;
      end if;
   end process conf_a_proc;


   --------------
   -- Port B
   --------------

   conf_b_proc : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         b_config_o <= config;
      end if;
   end process conf_b_proc;

end Structural;

