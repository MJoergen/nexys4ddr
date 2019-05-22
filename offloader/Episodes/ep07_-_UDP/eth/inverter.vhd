library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module is a small test module that inverts everything received.

entity inverter is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Connected to Ethernet module
      rx_data_i  : in  std_logic_vector(7 downto 0);
      rx_sof_i   : in  std_logic;
      rx_eof_i   : in  std_logic;
      rx_valid_i : in  std_logic;
      --
      tx_empty_o : out std_logic;
      tx_rden_i  : in  std_logic;
      tx_data_o  : out std_logic_vector(7 downto 0);
      tx_sof_o   : out std_logic;
      tx_eof_o   : out std_logic
   );
end inverter;

architecture Structural of inverter is

   signal wr_en    : std_logic;
   signal wr_data  : std_logic_vector(15 downto 0);
   signal rd_empty : std_logic;
   signal rd_en    : std_logic;
   signal rd_data  : std_logic_vector(15 downto 0);

begin

   wr_en                 <= rx_valid_i;
   wr_data(15 downto 10) <= (others => '0');
   wr_data(9)            <= rx_sof_i;
   wr_data(8)            <= rx_eof_i;
   wr_data(7 downto 0)   <= not rx_data_i; -- This is where the inversion takes place.

   i_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16                             -- Must be a power of two.
   )
   port map (
      wr_clk_i   => clk_i,
      wr_rst_i   => rst_i,
      wr_en_i    => wr_en,
      wr_data_i  => wr_data,
      wr_error_o => open,
      rd_clk_i   => clk_i,
      rd_rst_i   => rst_i,
      rd_en_i    => rd_en,
      rd_data_o  => rd_data,
      rd_empty_o => rd_empty,
      rd_error_o => open
   ); -- i_fifo

   rd_en <= tx_rden_i;
   tx_empty_o <= rd_empty;
   tx_sof_o   <= rd_data(9);
   tx_eof_o   <= rd_data(8);
   tx_data_o  <= rd_data(7 downto 0);

end Structural;

