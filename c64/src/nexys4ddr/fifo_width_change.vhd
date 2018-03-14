-- Description:
-- This is an asymmetric FIFO, where the write port is wider than the read port.
-- The ratio is defined as G_WRPORT_SIZE / G_RDPORT_SIZE, and must be a whole
-- number.
--
-- There is a separate read and write clock.
--
-- Endianness:
-- Assume that the write side is 40 bits and the read side is 10 bits, i.e. the
-- ratio is 4. The write port contains four chunks of data, as shown below:
-- 
-- Bit: |3   3|2   2|1   1|     |
--      |9   0|9   0|9   0|9   0|
--      +-----+-----+-----+-----+
--      |  D  |  C  |  B  |  A  |
--      +-----+-----+-----+-----+
--
-- From the read port, chunk A is read first and chunk D is read last.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity fifo_width_change is
   generic (
      G_WRPORT_SIZE : integer;     -- Number of data bits on write port.
      G_RDPORT_SIZE : integer      -- Number of data bits on read port.
      );
   port (
      -- Write port
      wr_clk_i   : in  std_logic;
      wr_rst_i   : in  std_logic;
      wr_en_i    : in  std_logic;
      wr_data_i  : in  std_logic_vector(G_WRPORT_SIZE-1 downto 0);

      -- Read port
      rd_clk_i   : in  std_logic;
      rd_rst_i   : in  std_logic;
      rd_en_i    : in  std_logic;
      rd_data_o  : out std_logic_vector(G_RDPORT_SIZE-1 downto 0);
      rd_empty_o : out std_logic
      );
end entity fifo_width_change;

architecture rtl of fifo_width_change is

   -- The ratio between the write and read side.
   constant C_NUM_FIFOS : integer := G_WRPORT_SIZE / G_RDPORT_SIZE;

   -- Signals for the internal FIFOs
   signal fifo_rden  : std_logic_vector(C_NUM_FIFOS-1 downto 0);
   signal fifo_data  : std_logic_vector(G_RDPORT_SIZE*C_NUM_FIFOS-1 downto 0);
   signal fifo_empty : std_logic_vector(C_NUM_FIFOS-1 downto 0);
   signal fifo_error : std_logic_vector(C_NUM_FIFOS-1 downto 0);

   signal rd_offset : integer range 0 to C_NUM_FIFOS-1 := 0;

begin

   ----------------------------
   -- Generate individual FIFOS
   ----------------------------

   enc_fifos : for i in 0 to C_NUM_FIFOS-1 generate
      inst_fifo : entity work.fifo
         generic map (
            G_WIDTH => G_RDPORT_SIZE
         )
         port map (
            wr_clk_i   => wr_clk_i,
            wr_rst_i   => wr_rst_i,
            wr_en_i    => wr_en_i,
            wr_data_i  => wr_data_i((i+1)*G_RDPORT_SIZE-1 downto i*G_RDPORT_SIZE),
            wr_error_o => fifo_error(i),
            --
            rd_clk_i   => rd_clk_i,
            rd_rst_i   => rd_rst_i,
            rd_en_i    => fifo_rden(i),
            rd_data_o  => fifo_data((i+1)*G_RDPORT_SIZE-1 downto i*G_RDPORT_SIZE),
            rd_empty_o => fifo_empty(i),
            rd_error_o => open
            --
            );
   end generate enc_fifos;


   ------------------------
   -- Reading from the FIFO
   ------------------------

   p_rd_offset : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         if rd_en_i = '1' then
            rd_offset <= (rd_offset+1) mod C_NUM_FIFOS;
         end if;

         if rd_rst_i = '1' then
            rd_offset <= 0;
         end if;
      end if;
   end process p_rd_offset;

   -- Combinatorial process
   p_enc_fifo_rden : process (rd_offset, rd_en_i)
   begin
      fifo_rden            <= (others => '0');
      fifo_rden(rd_offset) <= rd_en_i;
   end process p_enc_fifo_rden;

   -- Drive output signals
   rd_data_o   <= fifo_data((rd_offset+1)*G_RDPORT_SIZE-1 downto rd_offset*G_RDPORT_SIZE);
   rd_empty_o  <= fifo_empty(rd_offset);

end architecture rtl;

