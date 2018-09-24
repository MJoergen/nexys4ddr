library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple Transmit DMA.  To send an Ethernet frame, the user must
-- prepare a contiguous memory area containing the Ethernet frame prepended
-- with a two-byte header containing the length of the frame. Then the user
-- must write the pointer to the start of this buffer to ETH_TX_PTR, and
-- then write a 1 to ETH_TX_CTRL.
-- When the Transmit DMA has read the contents of the memory, the value
-- of ETH_TX_CTRL will be cleared to zero.
--
-- This module monitors the memio_i signal, waiting for bit 16 to become 1.
-- Then it performs a series of reads from memory, and finally sets
-- memio_clear_o to 1.

entity tx_dma is
   port (
      clk_i         : in  std_logic;

      memio_i       : in  std_logic_vector(23 downto 0);
      memio_clear_o : out std_logic;

      rd_addr_o     : out std_logic_vector(15 downto 0);
      rd_en_o       : out std_logic;
      rd_data_i     : in  std_logic_vector( 7 downto 0);

      wr_afull_i    : in  std_logic;
      wr_valid_o    : out std_logic;
      wr_data_o     : out std_logic_vector( 7 downto 0);
      wr_eof_o      : out std_logic
   );
end tx_dma;

architecture Structural of tx_dma is

   signal memio_clear : std_logic;
   signal rd_addr     : std_logic_vector(15 downto 0);
   signal rd_en       : std_logic;
   signal rd_len      : std_logic_vector(15 downto 0);

   signal wr_valid    : std_logic;
   signal wr_data     : std_logic_vector( 7 downto 0);

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, LEN_LO_ST, LEN_HI_ST, DATA_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

begin

   proc_read : process (clk_i)
   begin
      if rising_edge(clk_i) then
         memio_clear <= '0';
         rd_en       <= '0';
         wr_valid    <= '0';
         case fsm_state is
            when IDLE_ST =>
               if memio_i(0) = '1' then
                  if rd_en = '0' then  -- Only read every other clock cycle.
                     rd_addr   <= memio_i(23 downto 8);
                     rd_en     <= '1';
                     fsm_state <= LEN_LO_ST;
                  end if;
               end if;

            when LEN_LO_ST =>
               if rd_en = '1' then  -- Only read every other clock cycle.
                  rd_len(7 downto 0) <= rd_data_i;
               else
                  rd_addr   <= rd_addr + 1;
                  rd_en     <= '1';
                  fsm_state <= LEN_HI_ST;
               end if;

            when LEN_HI_ST =>
               if rd_en = '1' then  -- Only read every other clock cycle.
                  rd_len(15 downto 8) <= rd_data_i;
               else
                  rd_addr   <= rd_addr + 1;
                  rd_en     <= '1';
                  fsm_state <= DATA_ST;
               end if;

            when DATA_ST =>
               if rd_len /= 0 then
                  if rd_en = '1' then  -- Only read every other clock cycle.
                     wr_data   <= rd_data_i;
                  else
                     wr_valid  <= '1';
                     rd_addr   <= rd_addr + 1;
                     rd_en     <= '1';
                  end if;
               else
                  memio_clear <= '1';
                  fsm_state   <= IDLE_ST;
               end if;

         end case;
      end if;
   end process proc_read;

   -- Connect output signals
   memio_clear_o <= memio_clear;
   rd_addr_o     <= rd_addr;
   rd_en_o       <= rd_en;
   wr_valid_o    <= wr_valid;
   wr_data_o     <= wr_data;

end Structural;

