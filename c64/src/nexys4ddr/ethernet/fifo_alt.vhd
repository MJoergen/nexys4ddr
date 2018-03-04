library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

entity fifo is
   generic (
      G_WIDTH : natural := 8);
   port (
      wr_clk_i   : in  std_logic;
      wr_en_i    : in  std_logic;
      wr_data_i  : in  std_logic_vector(G_WIDTH-1 downto 0);
      --
      rd_clk_i    : in  std_logic;
      rd_rst_i    : in  std_logic;
      rd_en_i     : in  std_logic;
      rd_data_o   : out std_logic_vector(G_WIDTH-1 downto 0);
      rd_empty_o  : out std_logic
      );
end entity fifo;

architecture behavioral of fifo is

   signal fifo_in  : std_logic_vector(31 downto 0);
   signal fifo_out : std_logic_vector(31 downto 0);

begin  -- architecture behavioral

   fifo_in(G_WIDTH-1 downto 0) <= wr_data_i;
   fifo_in(31 downto G_WIDTH) <= (others => '0');

   rd_data_o <= fifo_out(G_WIDTH-1 downto 0);

   inst_FIFO18E1 : FIFO18E1
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
         RST           => rd_rst_i,
         RSTREG        => '0',
         REGCE         => '0',
         DO            => fifo_out,
         DOP           => open,
         FULL          => open,
         ALMOSTFULL    => open,
         EMPTY         => rd_empty_o,
         ALMOSTEMPTY   => open,
         RDCOUNT       => open,
         WRCOUNT       => open,
         WRERR         => open,
         RDERR         => open);

end architecture behavioral;

