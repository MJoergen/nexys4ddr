library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity wide_fifo is
   port (
      a_clk_i     : in  std_logic;
      a_rst_i     : in  std_logic;
      a_valid_i   : in  std_logic;
      a_data_i    : in  std_logic_vector(60*8-1 downto 0);
      a_last_i    : in  std_logic;
      a_bytes_i   : in  std_logic_vector(5 downto 0);

      b_clk_i     : in  std_logic;
      b_rst_i     : in  std_logic;
      b_valid_o   : out std_logic;
      b_data_o    : out std_logic_vector(60*8-1 downto 0);
      b_last_o    : out std_logic;
      b_bytes_o   : out std_logic_vector(5 downto 0)
   );
end wide_fifo;

architecture structural of wide_fifo is

   signal a_fifo_in  : std_logic_vector(60*8-1 + 8 + 1 downto 0);

   signal b_fifo_out : std_logic_vector(60*8-1 + 8 + 1 downto 0);
   signal b_rden     : std_logic;
   signal b_empty    : std_logic;

begin
   
   --------------------------------------------------
   -- Instantiate Clock Domain Crossing
   --------------------------------------------------


   a_fifo_in(60*8-1 downto 0)       <= a_data_i;
   a_fifo_in(60*8+5 downto 60*8)    <= a_bytes_i;
   a_fifo_in(60*8+7 downto 60*8+6)  <= "00";
   a_fifo_in(60*8+8)                <= a_last_i;

   i_fifo : entity work.fifo
   generic map (
      G_WIDTH => a_fifo_in'length
   )
   port map (
      wr_clk_i   => a_clk_i,
      wr_rst_i   => a_rst_i,
      wr_en_i    => a_valid_i,
      wr_data_i  => a_fifo_in,
      rd_clk_i   => b_clk_i,
      rd_rst_i   => b_rst_i,
      rd_en_i    => b_rden,
      rd_data_o  => b_fifo_out,
      rd_empty_o => b_empty
   ); -- i_fifo

   p_b_rden : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then

         b_rden    <= '0';
         b_valid_o <= '0';
         b_data_o  <= b_fifo_out(60*8-1 downto 0);
         b_bytes_o <= b_fifo_out(60*8+5 downto 60*8);
         b_last_o  <= b_fifo_out(60*8+8);

         if b_rden = '0' and b_empty = '0' then
            b_rden    <= '1';
            b_valid_o <= '1';
         end if;
      end if;
   end process p_b_rden;

end architecture structural;

