library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

Library xpm;
use xpm.vcomponents.all;

-- This module handles clock crossing using a Xilinx FIFO.
-- The FIFO is written to whenever it is empty,
-- and read from whenever it is not empty.

entity cdc is
   generic (
      G_WIDTH : integer
   );
   port (
      src_clk_i  : in  std_logic;
      src_rst_i  : in  std_logic;
      src_data_i : in  std_logic_vector(G_WIDTH-1 downto 0);
      dst_clk_i  : in  std_logic;
      dst_data_o : out std_logic_vector(G_WIDTH-1 downto 0)
   );
end cdc;

architecture structural of cdc is

   signal dst_empty       : std_logic;
   signal dst_rd_en       : std_logic;

   signal src_prog_full   : std_logic;
   signal src_wr_en       : std_logic;
   signal src_wr_rst_busy : std_logic;

begin

   -- Write when empty
   src_wr_en <= not src_prog_full and not src_wr_rst_busy;

   -- Read when not empty
   dst_rd_en <= not dst_empty;

   ---------------------------------------------
   -- Instantiate FIFO to handle clock crossing
   ---------------------------------------------

   xpm_fifo_async_inst : xpm_fifo_async
   generic map (
      FIFO_READ_LATENCY    => 0,
      FIFO_WRITE_DEPTH     => 16,      -- The smallest possible value
      RD_DATA_COUNT_WIDTH  => 1,       -- Not used
      READ_DATA_WIDTH      => G_WIDTH,
      READ_MODE            => "fwft",
      WRITE_DATA_WIDTH     => G_WIDTH,
      WR_DATA_COUNT_WIDTH  => 1        -- Not used
   )
   port map (
      almost_empty         => open,
      almost_full          => open,
      data_valid           => open,
      dbiterr              => open ,
      din                  => src_data_i,
      dout                 => dst_data_o,
      empty                => dst_empty,
      full                 => open,
      injectdbiterr        => '0',
      injectsbiterr        => '0',
      overflow             => open,
      prog_empty           => open,
      prog_full            => src_prog_full,
      rd_clk               => dst_clk_i,
      rd_data_count        => open,
      rd_en                => dst_rd_en,
      rd_rst_busy          => open,
      rst                  => src_rst_i,
      sbiterr              => open,
      sleep                => '0',
      underflow            => open,
      wr_ack               => open,
      wr_clk               => src_clk_i,
      wr_data_count        => open,
      wr_en                => src_wr_en,
      wr_rst_busy          => src_wr_rst_busy
   ); -- xpm_fifo_async_inst

end architecture structural;

