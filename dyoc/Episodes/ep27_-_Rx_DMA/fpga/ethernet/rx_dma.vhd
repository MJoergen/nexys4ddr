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

entity rx_dma is
   port (
      clk_i        : in  std_logic;

      -- Connected to Rx FIFO
      rd_empty_i   : in  std_logic;
      rd_en_o      : out std_logic;
      rd_data_i    : in  std_logic_vector(7 downto 0);
      rd_eof_i     : in  std_logic;

      -- Connected to RAM
      wr_en_o      : out std_logic;
      wr_addr_o    : out std_logic_vector(15 downto 0);
      wr_data_o    : out std_logic_vector( 7 downto 0);

      -- Connected to memio
      dma_enable_i : in  std_logic;
      dma_ptr_i    : in  std_logic_vector(15 downto 0);
      dma_size_i   : in  std_logic_vector(15 downto 0);
      cpu_ptr_i    : in  std_logic_vector(15 downto 0);
      buf_ptr_o    : out std_logic_vector(15 downto 0);
      buf_size_o   : out std_logic_vector(15 downto 0)
   );
end rx_dma;

architecture Structural of rx_dma is

   signal rd_en    : std_logic := '0';

   signal wr_en    : std_logic;
   signal wr_addr  : std_logic_vector(15 downto 0);
   signal wr_data  : std_logic_vector( 7 downto 0);

   signal buf_ptr  : std_logic_vector(15 downto 0);
   signal buf_size : std_logic_vector(15 downto 0);

begin

   wr_en   <= rd_en;
   wr_data <= rd_data_i;


   -------------------------------------
   -- Calculate the address to write the NEXT byte to.
   -------------------------------------

   proc_wr_addr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en = '1' then
            wr_addr <= wr_addr + 1;

            -- If end of packet, check if remaining buffer can support a full frame.
            -- If not, reset write pointer to start of receive buffer.
            if rd_eof_i = '1' and (dma_ptr_i + dma_size_i - wr_addr) < X"0600" then
               wr_addr <= dma_ptr_i;
            end if;
         end if;

         if dma_enable_i = '0' then   -- Reset write pointer to beginning of new buffer location.
            wr_addr <= dma_ptr_i;
         end if;
      end if;
   end process proc_wr_addr;


   ----------------------------------------------
   -- This generates a read on every second cycle,
   -- unless buffer is full.
   ----------------------------------------------

   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rd_en <= not rd_empty_i and not rd_en;
         
         -- Don't read any more, if buffer is full.
         if dma_enable_i = '1' then
            if wr_addr + 1 = cpu_ptr_i or
               (wr_addr = dma_ptr_i + dma_size_i) then
               rd_en <= '0';
            end if;
         end if;
      end if;
   end process proc_read;


   proc_buf_ptr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en = '1' and rd_eof_i = '1' then
            buf_size <= wr_addr + 1 - buf_ptr;
         end if;

         if dma_enable_i = '0' then   -- Reset write pointer to beginning of new buffer location.
            buf_ptr  <= dma_ptr_i;
            buf_size <= (others => '0');
         end if;
      end if;
   end process proc_buf_ptr;


   --------------------------- 
   -- Connect output signals
   --------------------------- 

   rd_en_o    <= rd_en;

   wr_en_o    <= wr_en;
   wr_addr_o  <= wr_addr;
   wr_data_o  <= wr_data;

   buf_ptr_o  <= buf_ptr;
   buf_size_o <= buf_size;

end Structural;

