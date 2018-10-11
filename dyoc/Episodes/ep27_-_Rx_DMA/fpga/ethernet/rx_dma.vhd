library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple DMA. It will generate write requests to the memory,
-- whenever there is input data available.  Since this DMA has priority over
-- the CPU, writes are only generated every second clock cycle, to avoid
-- starving the CPU for long periods. This is still enough to provide
-- an effective data rate of 100 Mbit/s (25MHz / 2 * 8 bits/byte).
--
-- The buffer location in memory is supplied in the signals dma_ptr_i and
-- dma_size_i. Prior to changing these signals, the dma_enable_i must be
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

   -- Output signals
   signal rd_en    : std_logic;
   signal wr_en    : std_logic;
   signal wr_addr  : std_logic_vector(15 downto 0);
   signal wr_data  : std_logic_vector( 7 downto 0);
   signal buf_ptr  : std_logic_vector(15 downto 0);
   signal buf_size : std_logic_vector(15 downto 0);

   signal buf_start : std_logic_vector(15 downto 0);
   signal buf_end   : std_logic_vector(15 downto 0);

   type state_t is (IDLE_ST, DATA_ST, WAIT_ST);
   signal state : state_t := IDLE_ST;

begin

   fsm_proc : process(clk_i)
   begin
      if rising_edge(clk_i) then

         -- Default values
         rd_en <= '0';
         wr_en <= '0';

         wr_data <= rd_data_i;

         if wr_en = '1' then
            wr_addr <= wr_addr + 1;
         end if;

         buf_ptr  <= cpu_ptr_i;
         buf_size <= buf_end - cpu_ptr_i;

         case state is
            when IDLE_ST =>
               if cpu_ptr_i = dma_ptr_i then
                  buf_start <= dma_ptr_i;
                  buf_end   <= dma_ptr_i;
                  buf_size  <= (others => '0');
                  if rd_empty_i = '0' then
                     wr_addr   <= dma_ptr_i;
                     state     <= DATA_ST;
                  end if;
               end if;

            when DATA_ST =>
               if rd_empty_i = '0' and rd_en = '0' then
                  rd_en <= '1';
                  wr_en <= '1';

                  if rd_eof_i = '1' then
                     buf_end  <= wr_addr + 1;
                     state    <= WAIT_ST;
                  end if;
               end if;

            when WAIT_ST =>
               if cpu_ptr_i = buf_end then
                  state   <= IDLE_ST;
               end if;

         end case;

         if dma_enable_i = '0' then
            state    <= IDLE_ST;
            wr_addr  <= dma_ptr_i;
            wr_data  <= (others => '0');
            buf_ptr  <= dma_ptr_i;
            buf_size <= (others => '0');

            buf_start <= dma_ptr_i;
            buf_end   <= dma_ptr_i;
         end if;
      end if;
   end process fsm_proc;


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

