library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module takes a parallel input and serializes it one-byte-at-a-time.
-- The MSB is transmitted first, i.e. hdr_data_i(G_PL_SIZE*8-1 downto
-- G_PL_SIZE*8-8).

entity wide2byte is
   generic (
      G_PL_SIZE   : integer := 60
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Receive interface (wide data bus)
      hdr_valid_i : in  std_logic;
      hdr_size_i  : in  std_logic_vector(7 downto 0);
      hdr_data_i  : in  std_logic_vector(G_PL_SIZE*8-1 downto 0);
      hdr_more_i  : in  std_logic;

      -- Receive interface (byte oriented data bus)
      pl_valid_i  : in  std_logic;
      pl_eof_i    : in  std_logic;
      pl_data_i   : in  std_logic_vector(7 downto 0);

      -- Transmit interface (byte oriented data bus)
      tx_empty_o  : out std_logic;
      tx_rden_i   : in  std_logic;
      tx_data_o   : out std_logic_vector(7 downto 0);
      tx_sof_o    : out std_logic;
      tx_eof_o    : out std_logic
   );
end wide2byte;

architecture Structural of wide2byte is

   type t_state is (IDLE_ST, HDR_ST, PL_ST);
   signal state_r    : t_state := IDLE_ST;

   signal size_r     : std_logic_vector(7 downto 0);
   signal data_r     : std_logic_vector(G_PL_SIZE*8-1 downto 0);
   signal more_r     : std_logic;

   signal wr_en      : std_logic;
   signal wr_data    : std_logic_vector(15 downto 0);
   signal rd_empty   : std_logic;
   signal rd_en      : std_logic;
   signal rd_data    : std_logic_vector(15 downto 0);

   signal tx_empty_r : std_logic;
   signal tx_data_r  : std_logic_vector(7 downto 0);
   signal tx_sof_r   : std_logic;
   signal tx_eof_r   : std_logic;
      
begin

   -- Store payload data in a fifo
   wr_en                <= pl_valid_i;
   wr_data(15 downto 9) <= (others => '0');
   wr_data(8)           <= pl_eof_i;
   wr_data(7 downto 0)  <= pl_data_i;

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


   p_state : process (clk_i)
   begin
      if rising_edge(clk_i) then

         case state_r is
            when IDLE_ST =>
               more_r <= '0';
               if hdr_valid_i = '1' then
                  tx_empty_r <= '0';
                  tx_sof_r   <= '1';
                  tx_eof_r   <= '0';
                  tx_data_r  <= hdr_data_i(G_PL_SIZE*8-1 downto G_PL_SIZE*8-8);
                  data_r     <= hdr_data_i(G_PL_SIZE*8-9 downto 0) & X"00";
                  size_r     <= hdr_size_i-1;
                  more_r     <= hdr_more_i;
                  state_r    <= HDR_ST;
               end if;

            when HDR_ST =>
               if tx_rden_i = '1' then
                  tx_sof_r   <= '0';
                  tx_data_r  <= data_r(G_PL_SIZE*8-1 downto G_PL_SIZE*8-8);
                  data_r     <= data_r(G_PL_SIZE*8-9 downto 0) & X"00";
                  size_r     <= size_r-1;
                  if size_r-1 = 0 and more_r = '0' then
                     tx_eof_r <= '1';
                  end if;
                  if size_r = 0 and more_r = '0' then
                     tx_empty_r <= '1';
                     tx_eof_r   <= '0';
                     tx_data_r  <= X"00";
                     state_r    <= IDLE_ST;
                  end if;
                  if size_r = 0 and more_r = '1' then
                     tx_empty_r <= '1';
                     state_r    <= PL_ST;
                  end if;
               end if;

            when PL_ST =>
               if tx_rden_i = '1' then
                  if tx_eof_o = '1' then
                     state_r <= IDLE_ST;
                  end if;
               end if;

         end case;

         if rst_i = '1' then
            tx_empty_r <= '1';
            tx_sof_r   <= '0';
            tx_eof_r   <= '0';
            tx_data_r  <= X"00";
            state_r    <= IDLE_ST;
         end if;
      end if;
   end process p_state;

   -- Drive output signals
   tx_empty_o <= rd_empty            when state_r = PL_ST else tx_empty_r;
   tx_sof_o   <= rd_data(9)          when state_r = PL_ST else tx_sof_r;
   tx_eof_o   <= rd_data(8)          when state_r = PL_ST else tx_eof_r;
   tx_data_o  <= rd_data(7 downto 0) when state_r = PL_ST else tx_data_r;

   rd_en      <= tx_rden_i           when state_r = PL_ST else '0';

end Structural;

