library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

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
      rst_i        : in  std_logic;

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
      dma_ptr_i    : in  std_logic_vector(15 downto 0);
      dma_enable_i : in  std_logic;
      dma_clear_o  : out std_logic
   );
end rx_dma;

architecture structural of rx_dma is

   -- Output signals
   signal rd_en     : std_logic;
   signal wr_en     : std_logic;
   signal wr_addr   : std_logic_vector(15 downto 0);
   signal wr_data   : std_logic_vector( 7 downto 0);
   signal dma_clear : std_logic;

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

         case state is
            when IDLE_ST =>
               if dma_enable_i = '1' and rd_empty_i = '0' then
                  wr_addr <= dma_ptr_i;
                  state   <= DATA_ST;
               end if;

            when DATA_ST =>
               if rd_empty_i = '0' and rd_en = '0' then
                  rd_en <= '1';
                  wr_en <= '1';

                  if rd_eof_i = '1' then
                     dma_clear <= '1';
                     state     <= WAIT_ST;
                  end if;
               end if;

            when WAIT_ST =>
               if dma_enable_i = '0' then
                  dma_clear <= '0';
                  state     <= IDLE_ST;
               end if;

         end case;

         if rst_i = '1' then
            dma_clear <= '0';
            state <= IDLE_ST;
         end if;
      end if;
   end process fsm_proc;


   --------------------------- 
   -- Connect output signals
   --------------------------- 

   rd_en_o     <= rd_en;
   wr_en_o     <= wr_en;
   wr_addr_o   <= wr_addr;
   wr_data_o   <= wr_data;
   dma_clear_o <= dma_clear;

end structural;

