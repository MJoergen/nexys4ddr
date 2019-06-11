library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

-- This module is a wrapper for a FIFO consisting
-- of several Xilinx-specific FIFOs in parallel.

entity fifo is
   generic (
      G_WIDTH : natural
   );
   port (
      wr_clk_i   : in  std_logic;
      wr_rst_i   : in  std_logic;
      wr_en_i    : in  std_logic;
      wr_data_i  : in  std_logic_vector(G_WIDTH-1 downto 0);
      wr_full_o  : out std_logic;
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

   constant C_FIFOS : integer := (G_WIDTH+71) / 72;

   signal rst      : std_logic;

   signal fifo_in  : std_logic_vector(C_FIFOS*72-1 downto 0);
   signal fifo_out : std_logic_vector(C_FIFOS*72-1 downto 0);

   signal wr_full  : std_logic_vector(C_FIFOS-1 downto 0);
   signal rd_empty : std_logic_vector(C_FIFOS-1 downto 0);
   signal rderr    : std_logic_vector(C_FIFOS-1 downto 0);
   signal wrerr    : std_logic_vector(C_FIFOS-1 downto 0);

   signal rderr_l  : std_logic;
   signal wrerr_l  : std_logic;

begin  -- architecture behavioral

   -- Global asynchronous reset. Common for read and write port.
   rst <= wr_rst_i or rd_rst_i;

   -- Prepare input data
   fifo_in(G_WIDTH-1    downto 0)       <= wr_data_i;
   fifo_in(C_FIFOS*72-1 downto G_WIDTH) <= (others => '0');

   -- Instantiate all the Xilinx fifos in parallel
   gen_fifos : for i in 0 to C_FIFOS-1 generate

      -- Instantiate a single Xilinx fifo
      i_FIFO36E1 : FIFO36E1
         GENERIC MAP (
            FIRST_WORD_FALL_THROUGH => true,
            FIFO_MODE               => "FIFO36_72",
            DATA_WIDTH              => 72,
            EN_SYN                  => false)
         PORT MAP (
            DI            => fifo_in(i*72+63 downto i*72),
            DIP           => fifo_in(i*72+71 downto i*72+64),
            WREN          => wr_en_i,
            WRCLK         => wr_clk_i,
            RDEN          => rd_en_i,
            RDCLK         => rd_clk_i,
            RST           => rst,
            RSTREG        => '0',
            REGCE         => '0',
            DO            => fifo_out(i*72+63 downto i*72),
            DOP           => fifo_out(i*72+71 downto i*72+64),
            FULL          => wr_full(i),
            ALMOSTFULL    => open,
            EMPTY         => rd_empty(i),
            ALMOSTEMPTY   => open,
            RDCOUNT       => open,
            WRCOUNT       => open,
            WRERR         => wrerr(i),
            RDERR         => rderr(i),
            INJECTDBITERR => '0',
            INJECTSBITERR => '0'
         ); -- i_FIFO36E1
   end generate gen_fifos;


   -- Latch read error
   proc_rderr : process (rd_clk_i)
   begin
      if rising_edge(rd_clk_i) then
         if rderr /= 0 then
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
         if wrerr /= 0 then
            wrerr_l <= '1';
         end if;
         if wr_rst_i = '1' then
            wrerr_l <= '0';
         end if;
      end if;
   end process proc_wrerr;

   -- Drive output siganls
   rd_data_o  <= fifo_out(G_WIDTH-1 downto 0);
   rd_empty_o <= rd_empty(0); -- All FIFOs are read from simultaneously, so they all have the same value of rd_empty.
   wr_full_o  <= wr_full(0);
   wr_error_o <= wrerr_l;
   rd_error_o <= rderr_l;

end architecture behavioral;

