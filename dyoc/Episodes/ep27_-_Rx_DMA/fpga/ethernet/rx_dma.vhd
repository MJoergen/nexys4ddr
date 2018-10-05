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
   signal buf_end  : std_logic_vector(15 downto 0);
   signal buf_size : std_logic_vector(15 downto 0);

   signal rd_eof_d       : std_logic;
   signal wait_for_cpu   : std_logic;
   signal wait_for_cpu_d : std_logic;

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

            if rd_eof_i = '1' and (dma_ptr_i + dma_size_i - wr_addr) < X"0600" and wait_for_cpu = '0' then
               wr_addr <= dma_ptr_i;
            end if;
         end if;

         if wait_for_cpu_d = '1' and wait_for_cpu = '0' then
            wr_addr <= dma_ptr_i;
         end if;

         if dma_enable_i = '0' then   -- Reset write pointer to beginning of new buffer location.
            wr_addr <= dma_ptr_i;
         end if;
      end if;
   end process proc_wr_addr;


   proc_wait_for_cpu : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rd_eof_i = '1' and (dma_ptr_i + dma_size_i - wr_addr) < X"0600" then
            if cpu_ptr_i /= wr_addr then
               wait_for_cpu <= '1';
            end if; 
         end if;

         if cpu_ptr_i = wr_addr then
            wait_for_cpu <= '0';
         end if; 

         wait_for_cpu_d <= wait_for_cpu;
      end if;
   end process proc_wait_for_cpu;


   ----------------------------------------------
   -- This generates a read on every second cycle,
   -- unless buffer is full.
   ----------------------------------------------

   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         rd_en <= not rd_empty_i and not rd_en;
         
         if dma_enable_i = '1' then
            -- Don't send any more, if we've reached the CPU pointer.
            if wr_addr + 1 = cpu_ptr_i then
               rd_en <= '0';
            end if;

            -- Don't start a new frame if not room.
            if wait_for_cpu = '1' then
               rd_en <= '0';
            end if;
         end if;

         rd_eof_d <= rd_eof_i;
      end if;
   end process proc_read;


   proc_buf_end : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en = '1' and rd_eof_i = '1' then
            buf_end <= wr_addr + 1;
         end if;

         if dma_enable_i = '0' then
            buf_end <= dma_ptr_i;
         end if;
      end if;
   end process proc_buf_end;

   proc_buf_size : process (clk_i)
   begin
      if rising_edge(clk_i) then
         buf_size <= buf_end - cpu_ptr_i;

         if dma_enable_i = '0' then
            buf_size <= (others => '0');
         end if;
      end if;
   end process proc_buf_size;

   proc_buf_ptr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_addr + 1 > cpu_ptr_i then
            buf_ptr <= cpu_ptr_i;
         end if;

         if dma_enable_i = '0' then   -- Reset write pointer to beginning of new buffer location.
            buf_ptr <= dma_ptr_i;
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

