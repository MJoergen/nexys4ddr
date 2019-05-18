library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

-- This module is a wrapper for the Xilinx-specific FIFO.
-- The error signals are latches, i.e. are only cleared on reset.
-- G_WIDTH must be a power of 2.

entity fifo is
   generic (
      G_WIDTH : natural := 8);
   port (
      wr_clk_i   : in  std_logic;
      wr_rst_i   : in  std_logic;
      wr_en_i    : in  std_logic;
      wr_data_i  : in  std_logic_vector(G_WIDTH-1 downto 0);
      wr_error_o : out std_logic;
      --
      rd_clk_i   : in  std_logic;
      rd_rst_i   : in  std_logic;
      rd_en_i    : in  std_logic;
      rd_data_o  : out std_logic_vector(G_WIDTH-1 downto 0);
      rd_empty_o : out std_logic;
      rd_error_o : out std_logic
      );
end entity fifo;

architecture behavioral of fifo is

   signal rst      : std_logic;

   signal fifo_in  : std_logic_vector(63 downto 0);
   signal fifo_out : std_logic_vector(63 downto 0);
   signal rd_empty : std_logic;

   signal rderr    : std_logic;
   signal wrerr    : std_logic;

   signal rderr_l  : std_logic;
   signal wrerr_l  : std_logic;

begin  -- architecture behavioral

   -- Global asynchronous reset. Common for read and write port.
   rst <= wr_rst_i or rd_rst_i;

   -- Prepare input data
   fifo_in(G_WIDTH-1 downto 0) <= wr_data_i;
   fifo_in(63 downto G_WIDTH)  <= (others => '0');

   -- Instantiate the Xilinx fifo
   inst_FIFO18E1 : FIFO36E1
      GENERIC MAP (
         FIRST_WORD_FALL_THROUGH => true,
         DATA_WIDTH              => (G_WIDTH*9)/8,
         EN_SYN                  => false)
      PORT MAP (
         DI            => fifo_in,
         DIP           => (others => '0'),
         WREN          => wr_en_i,
         WRCLK         => wr_clk_i,
         RDEN          => rd_en_i,
         RDCLK         => rd_clk_i,
         RST           => rst,
         RSTREG        => '0',
         REGCE         => '0',
         DO            => fifo_out,
         DOP           => open,
         FULL          => open,
         ALMOSTFULL    => open,
         EMPTY         => rd_empty,
         ALMOSTEMPTY   => open,
         RDCOUNT       => open,
         WRCOUNT       => open,
         WRERR         => wrerr,
         RDERR         => rderr,
         INJECTDBITERR => '0',
         INJECTSBITERR => '0');

   -- Latch read error
   proc_rderr : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         if rderr = '1' then
            rderr_l <= '1';
         end if;
         if rd_rst_i = '1' then
            rderr_l <= '0';
         end if;
      end if;
   end process proc_rderr;

   -- Latch write error
   proc_wrerr : process (wr_clk_i)
   begin
      if rising_edge(wr_clk_i) then
         if wrerr = '1' then
            wrerr_l <= '1';
         end if;
         if wr_rst_i = '1' then
            wrerr_l <= '0';
         end if;
      end if;
   end process proc_wrerr;

   -- Drive output siganls
   rd_data_o  <= fifo_out(G_WIDTH-1 downto 0);
   rd_empty_o <= rd_empty;
   wr_error_o <= wrerr_l;
   rd_error_o <= rderr_l;

end architecture behavioral;

