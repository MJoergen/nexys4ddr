library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

--Library xpm;
--use xpm.vcomponents.all;

-- This module handles clock crossing using a Xilinx FIFO.
-- The FIFO is written to whenever it is not full
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
      dst_rst_i  : in  std_logic;
      dst_data_o : out std_logic_vector(G_WIDTH-1 downto 0)
   );
end cdc;

architecture structural of cdc is

   signal src_en    : std_logic;
   signal src_full  : std_logic;
   signal dst_en    : std_logic;
   signal dst_empty : std_logic;

begin

   i_fifo : entity work.fifo
   generic map (
      G_WIDTH => G_WIDTH
   )
   port map (
      wr_clk_i   => src_clk_i,
      wr_rst_i   => src_rst_i,
      wr_en_i    => src_en,
      wr_data_i  => src_data_i,
      wr_full_o  => src_full,
      wr_error_o => open,
      rd_clk_i   => dst_clk_i,
      rd_rst_i   => dst_rst_i,
      rd_en_i    => dst_en,
      rd_data_o  => dst_data_o,
      rd_empty_o => dst_empty,
      rd_error_o => open
   ); -- i_fifo

--   p_src_en : process (src_clk_i)
--   begin
--      if rising_edge(src_clk_i) then
--         if src_rst_i = '1' then
--            src_en <= '0';
--         end if;
--      end if;
--   end process p_src_en;
--
--   p_dst_en : process (dst_clk_i)
--   begin
--      if rising_edge(dst_clk_i) then
--         dst_en <= not dst_empty;
--         if dst_rst_i = '1' then
--            dst_en <= '0';
--         end if;
--      end if;
--   end process p_dst_en;

   src_en <= not src_full and not src_rst_i;
   dst_en <= not dst_empty and not dst_rst_i;

end architecture structural;

