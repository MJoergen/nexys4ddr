library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple DMA. It will generate write requests to the memory,
-- whenever there is input data available.  Since this DMA has priority over
-- the CPU, writes are only generated every second clock cycle, to avoid
-- starving the CPU for long periods. This is still enough to provide
-- an effective data rate of 100 Mbit/s (25MHz / 2 * 8 bits/byte).
--
-- The buffer location in memory is supplied in the configuration signal
-- memio_i. Prior to changing this signal, the bit 48 (eth_enable) must be
-- cleared.

entity dma is
   port (
      clk_i      : in  std_logic;
      rd_empty_i : in  std_logic;
      rd_en_o    : out std_logic;
      rd_data_i  : in  std_logic_vector(7 downto 0);
      rd_error_i : in  std_logic_vector(1 downto 0);

      wr_en_o    : out std_logic;
      wr_addr_o  : out std_logic_vector(15 downto 0);
      wr_data_o  : out std_logic_vector( 7 downto 0);
      memio_i    : in  std_logic_vector(55 downto 0)
   );
end dma;

architecture Structural of dma is

   signal wr_en   : std_logic;
   signal wr_addr : std_logic_vector(15 downto 0);
   signal wr_data : std_logic_vector( 7 downto 0);

   signal rd_en   : std_logic := '0';

   signal eth_start  : std_logic_vector(15 downto 0);
   signal eth_end    : std_logic_vector(15 downto 0);
   signal eth_rdptr  : std_logic_vector(15 downto 0);
   signal eth_enable : std_logic;

begin

   eth_start  <= memio_i(15 downto  0);   -- Start of buffer.
   eth_end    <= memio_i(31 downto 16);   -- End of buffer.
   eth_rdptr  <= memio_i(47 downto 32);   -- Current CPU read pointer.
   eth_enable <= memio_i(48);             -- DMA enable. Must be cleared before updating buffer location.

   -- This generates a read on every second cycle.
   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rd_en <= not rd_empty_i and not rd_en;
      end if;
   end process proc_read;

   proc_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wr_en   <= rd_en;
         wr_data <= rd_data_i;
      end if;
   end process proc_write;

   -- Prepare wr_addr for the next byte.
   proc_wr_addr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en = '1' then
            if wr_addr + 1 = eth_end then
               wr_addr <= eth_start;
            else
               wr_addr <= wr_addr + 1;
            end if;
         end if;

         if eth_enable = '0' then   -- Reset write pointer to beginning of new buffer location.
            wr_addr <= eth_start;
         end if;
      end if;
   end process proc_wr_addr;


   -- Drive output signals
   rd_en_o   <= rd_en;
   wr_en_o   <= wr_en;
   wr_addr_o <= wr_addr;
   wr_data_o <= wr_data;

end Structural;

