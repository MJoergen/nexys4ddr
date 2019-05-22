library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module extracts the first (up to) G_HDR_SIZE of an incoming Ethernet
-- frame and forwards them as a wide data bus.  The remaining data is forwarded
-- byte-wise.
--
-- The first byte received is placed in MSB, i.e.  hdr_data_o(G_HDR_SIZE*8-1 downto G_HDR_SIZE*8-8);

entity byte2wide is
   generic (
      G_HDR_SIZE  : integer := 60    -- Default corresponding to minimum sized frame
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Receive interface (byte oriented data bus)
      rx_valid_i  : in  std_logic;
      rx_sof_i    : in  std_logic;
      rx_eof_i    : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);

      -- Header output (wide data bus)
      hdr_valid_o : out std_logic;
      hdr_data_o  : out std_logic_vector(G_HDR_SIZE*8-1 downto 0);
      hdr_size_o  : out std_logic_vector(7 downto 0);
      hdr_more_o  : out std_logic;  -- '1', if payload data follows

      -- Payload output (byte oriented data bus)
      pl_valid_o  : out std_logic;
      pl_eof_o    : out std_logic;
      pl_data_o   : out std_logic_vector(7 downto 0)
   );
end byte2wide;

architecture Structural of byte2wide is

   type t_state is (IDLE_ST, HDR_ST, PL_ST);
   signal state_r : t_state := IDLE_ST;

   signal hdr_valid_r : std_logic;
   signal hdr_data_r  : std_logic_vector(G_HDR_SIZE*8-1 downto 0);
   signal hdr_size_r  : std_logic_vector(7 downto 0);
   signal hdr_more_r  : std_logic;

   signal pl_valid_r  : std_logic;
   signal pl_eof_r    : std_logic;
   signal pl_data_r   : std_logic_vector(7 downto 0);

begin

   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         hdr_valid_r <= '0';
         hdr_more_r  <= '0';
         pl_valid_r  <= '0';
         pl_eof_r    <= '0';

         case state_r is
            when IDLE_ST =>
               if rx_valid_i = '1' and rx_sof_i = '1' then
                  hdr_data_r <= (others => '0');
                  hdr_data_r(G_HDR_SIZE*8-1 downto G_HDR_SIZE*8-8) <= rx_data_i;
                  hdr_size_r <= X"01";
                  state_r    <= HDR_ST;

                  -- We don't support frames of only 1 byte.
                  assert rx_eof_i = '0' report "Unexpected EOF" severity failure;
               end if;

            when HDR_ST =>
               if rx_valid_i = '1' then
                  hdr_data_r(G_HDR_SIZE*8-1-to_integer(hdr_size_r)*8 downto
                             G_HDR_SIZE*8-8-to_integer(hdr_size_r)*8) <= rx_data_i;
                  hdr_size_r <= hdr_size_r + 1;

                  -- If complete header is received, forward remaining data
                  -- one-byte-at-a-time.
                  if hdr_size_r+1 = G_HDR_SIZE then
                     hdr_valid_r <= '1';
                     hdr_more_r  <= '1';
                     state_r     <= PL_ST;
                  end if;

                  -- However, if this was the last byte, there is no more data.
                  if rx_eof_i = '1' then
                     hdr_valid_r <= '1';
                     hdr_more_r  <= '0';
                     state_r     <= IDLE_ST;
                  end if;
               end if;

            when PL_ST =>
               if rx_valid_i = '1' then
                  pl_valid_r <= '1';
                  pl_eof_r   <= rx_eof_i;
                  pl_data_r  <= rx_data_i;

                  if rx_eof_i = '1' then
                     state_r <= IDLE_ST;
                  end if;
               end if;
               
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Connnect output signals
   hdr_valid_o <= hdr_valid_r;
   hdr_data_o  <= hdr_data_r;
   hdr_size_o  <= hdr_size_r;
   hdr_more_o  <= hdr_more_r;

   pl_valid_o  <= pl_valid_r;
   pl_eof_o    <= pl_eof_r;
   pl_data_o   <= pl_data_r;

end Structural;

