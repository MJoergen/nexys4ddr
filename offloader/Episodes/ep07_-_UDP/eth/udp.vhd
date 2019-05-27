library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to UDP messages.

entity udp is
   generic (
      G_MY_MAC       : std_logic_vector(47 downto 0);
      G_MY_IP        : std_logic_vector(31 downto 0);
      G_MY_PORT      : std_logic_vector(15 downto 0)
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      debug_o        : out std_logic_vector(255 downto 0);

      -- Ingress from PHY
      rx_phy_valid_i : in  std_logic;
      rx_phy_data_i  : in  std_logic_vector(42*8-1 downto 0);
      rx_phy_last_i  : in  std_logic;
      rx_phy_bytes_i : in  std_logic_vector(5 downto 0);

      -- Ingress to client
      rx_cli_valid_o : out std_logic;
      rx_cli_data_o  : out std_logic_vector(42*8-1 downto 0);
      rx_cli_last_o  : out std_logic;
      rx_cli_bytes_o : out std_logic_vector(5 downto 0);

      -- Egress from client
      tx_cli_valid_i : in  std_logic;
      tx_cli_data_i  : in  std_logic_vector(42*8-1 downto 0);
      tx_cli_last_i  : in  std_logic;
      tx_cli_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress to PHY
      tx_phy_valid_o : out std_logic;
      tx_phy_data_o  : out std_logic_vector(42*8-1 downto 0);
      tx_phy_last_o  : out std_logic;
      tx_phy_bytes_o : out std_logic_vector(5 downto 0)
   );
end udp;

architecture Structural of udp is

   type t_rx_state is (IDLE_ST, FWD_ST);
   signal rx_state_r : t_rx_state := IDLE_ST;

   type t_tx_state is (IDLE_ST, FWD_ST);
   signal tx_state_r : t_tx_state := IDLE_ST;

   signal debug          : std_logic_vector(255 downto 0);

   -- Delayed input from client
   signal tx_cli_valid_d : std_logic;
   signal tx_cli_data_d  : std_logic_vector(42*8-1 downto 0);
   signal tx_cli_last_d  : std_logic;
   signal tx_cli_bytes_d : std_logic_vector(5 downto 0);

   signal tx_hdr       : std_logic_vector(42*8-1 downto 0);

   -- Header on egress frame
   signal tx_phy_valid : std_logic;
   signal tx_phy_data  : std_logic_vector(42*8-1 downto 0);
   signal tx_phy_last  : std_logic;
   signal tx_phy_bytes : std_logic_vector(5 downto 0);
   signal tx_phy_first : std_logic;

   -- The format of a MAC+IP+UDP header is as follows:
   -- 41 : MAC_DST[47 downto 40]       (Broadcast address)
   -- 40 : MAC_DST[39 downto 32]
   -- 39 : MAC_DST[31 downto 24]
   -- 38 : MAC_DST[23 downto 16]
   -- 37 : MAC_DST[15 downto  8]
   -- 36 : MAC_DST[ 7 downto  0]
   -- 35 : MAC_SRC[47 downto 40]
   -- 34 : MAC_SRC[39 downto 32]
   -- 33 : MAC_SRC[31 downto 24]
   -- 32 : MAC_SRC[23 downto 16]
   -- 31 : MAC_SRC[15 downto  8]
   -- 30 : MAC_SRC[ 7 downto  0]
   -- 29 : MAC_TYPELEN[15 downto 8]    = 08 (IP)
   -- 28 : MAC_TYPELEN[ 7 downto 0]    = 00
   -- 27 : IP_VIHL                     = 45 (IPv4)
   -- 26 : IP_DSCP
   -- 25 : IP_LENGTH[15 downto 8]
   -- 24 : IP_LENGTH[ 7 downto 0]
   -- 23 : IP_ID[15 downto 8]
   -- 22 : IP_ID[ 7 downto 0]
   -- 21 : IP_FRAG[15 downto 8]
   -- 20 : IP_FRAG[ 7 downto 0]
   -- 19 : IP_TTL
   -- 18 : IP_PROTOCOL                 = 01 (ICMP)
   -- 17 : IP_CHKSUM[15 downto 8]
   -- 16 : IP_CHKSUM[ 7 downto 0]
   -- 15 : IP_SRC[31 downto 24]
   -- 14 : IP_SRC[23 downto 16]
   -- 13 : IP_SRC[15 downto  8]
   -- 12 : IP_SRC[ 7 downto  0]
   -- 11 : IP_DST[31 downto 24]
   -- 10 : IP_DST[23 downto 16]
   -- 09 : IP_DST[15 downto  8]
   -- 08 : IP_DST[ 7 downto  0]
   -- 07 : UDP_SRC[15 downto 8]
   -- 06 : UDP_SRC[ 7 downto 0]
   -- 05 : UDP_DST[15 downto 8]
   -- 04 : UDP_DST[ 7 downto 0]
   -- 03 : UDP_LEN[15 downto 8]
   -- 02 : UDP_LEN[ 7 downto 0]
   -- 01 : UDP_CHKSUM[15 downto 8]
   -- 00 : UDP_CHKSUM[ 7 downto 0]

   -- Calculate the Internet Checksum according to RFC 1071.
   function checksum(inp : std_logic_vector) return std_logic_vector is
      variable res_v : std_logic_vector(19 downto 0) := (others => '0');
      variable val_v : std_logic_vector(15 downto 0);
   begin
      for i in 0 to inp'length/16-1 loop
         val_v := inp(i*16+15+inp'right downto i*16+inp'right);
         res_v := res_v + (X"0" & val_v);
      end loop;

      -- Handle wrap-around
      res_v := (X"0" & res_v(15 downto 0)) + (X"0000" & res_v(19 downto 16));
      return res_v(15 downto 0);
   end function checksum;

begin

   --------------------------------------------------
   -- Generate debug signals.
   -- This will store bytes 10-41 of the received frame.
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if tx_phy_valid = '1' and tx_phy_first = '1' then
            debug <= tx_phy_data(255 downto 0);
         end if;
         if tx_phy_valid = '1' then
            tx_phy_first <= tx_phy_last;
         end if;
         if rst_i = '1' then
            debug        <= (others => '1');
            tx_phy_first <= '1';
         end if;         
      end if;
   end process p_debug;


   --------------------------------------------------
   -- Instantiate ingress state machine
   --------------------------------------------------

   p_udp_rx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case rx_state_r is
            when IDLE_ST =>
               if rx_phy_valid_i = '1' and rx_phy_last_i = '0' then                     -- More data follows
                  -- Is this an UDP packet for our IP address and UDP port?
                  if rx_phy_data_i(29*8+7 downto 27*8) = X"080045" and                  -- IPv4 packet
                     rx_phy_data_i(18*8+7 downto 18*8) = X"11" and                      -- UDP protocol
                     rx_phy_data_i(11*8+7 downto  8*8) = G_MY_IP and                    -- For us
                     checksum(rx_phy_data_i(27*8+7 downto 8*8)) = X"FFFF" and           -- IP header checksum correct
                     rx_phy_data_i( 5*8+7 downto  4*8) = G_MY_PORT then                 -- UDP port
                     -- TBD: Add UDP header checksum verification.

                     -- Build response:
                     -- MAC header
                     tx_hdr(41*8+7 downto 36*8) <= rx_phy_data_i(35*8+7 downto 30*8);   -- MAC_DST
                     tx_hdr(35*8+7 downto 30*8) <= G_MY_MAC;                            -- MAC_SRC
                     tx_hdr(29*8+7 downto 28*8) <= X"0800";                             -- MAC_TYPELEN
                     -- IP header
                     tx_hdr(27*8+7 downto 27*8) <= X"45";                               -- IP_VIHL
                     tx_hdr(26*8+7 downto 26*8) <= X"00";                               -- IP_DSCP
                     tx_hdr(25*8+7 downto 24*8) <= rx_phy_data_i(25*8+7 downto 24*8);   -- IP_LENGTH
                     tx_hdr(23*8+7 downto 22*8) <= X"0000";                             -- IP_ID
                     tx_hdr(21*8+7 downto 20*8) <= X"0000";                             -- IP_FRAG
                     tx_hdr(19*8+7 downto 19*8) <= X"40";                               -- IP_TTL
                     tx_hdr(18*8+7 downto 18*8) <= X"11";                               -- IP_PROTOCOL = UDP
                     tx_hdr(17*8+7 downto 16*8) <= X"0000";                             -- IP_CHKSUM
                     tx_hdr(15*8+7 downto 12*8) <= G_MY_IP;                             -- IP_SRC
                     tx_hdr(11*8+7 downto  8*8) <= rx_phy_data_i(15*8+7 downto 12*8);   -- IP_DST
                     -- UDP header
                     tx_hdr( 7*8+7 downto  6*8) <= rx_phy_data_i( 5*8+7 downto  4*8);   -- UDP_SRC
                     tx_hdr( 5*8+7 downto  4*8) <= rx_phy_data_i( 7*8+7 downto  6*8);   -- UDP_DST
                     tx_hdr( 3*8+7 downto  2*8) <= rx_phy_data_i( 3*8+7 downto  2*8);   -- UDP_LEN
                     tx_hdr( 1*8+7 downto  0*8) <= X"0000";                             -- UDP_CHKSUM

                     rx_state_r <= FWD_ST;
                  end if;
               end if;

            when FWD_ST =>
               if rx_phy_valid_i = '1' and rx_phy_last_i = '1' then
                  rx_state_r <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            rx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp_rx;

   -- Connect ingress signals to client
   rx_cli_data_o  <= rx_phy_data_i  when rx_state_r = FWD_ST else (others => '0');
   rx_cli_last_o  <= rx_phy_last_i  when rx_state_r = FWD_ST else '0';
   rx_cli_bytes_o <= rx_phy_bytes_i when rx_state_r = FWD_ST else (others => '0');
   rx_cli_valid_o <= rx_phy_valid_i when rx_state_r = FWD_ST else '0';


   --------------------------------------------------
   -- Instantiate egress state machine
   --------------------------------------------------

   p_udp_tx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Default values
         tx_phy_valid <= '0';
         tx_phy_data  <= (others => '0');
         tx_phy_last  <= '0';
         tx_phy_bytes <= (others => '0');

         -- Input pipeline
         tx_cli_valid_d <= tx_cli_valid_i;
         tx_cli_data_d  <= tx_cli_data_i;
         tx_cli_last_d  <= tx_cli_last_i;
         tx_cli_bytes_d <= tx_cli_bytes_i;

         case tx_state_r is
            when IDLE_ST =>
               if tx_cli_valid_i = '1' then
                  tx_phy_valid <= '1';
                  -- Calculate checksum of IP header
                  tx_phy_data  <= tx_hdr;
                  tx_phy_data(17*8+7 downto 16*8) <= not checksum(tx_hdr(27*8+7 downto 8*8));
                  tx_phy_last  <= '0';
                  tx_phy_bytes <= (others => '0');
                  tx_state_r   <= FWD_ST;
               end if;

            when FWD_ST =>
               if tx_cli_valid_d = '1' then
                  tx_phy_valid <= '1';
                  tx_phy_data  <= tx_cli_data_d;
                  tx_phy_last  <= tx_cli_last_d;
                  tx_phy_bytes <= tx_cli_bytes_d;

                  if tx_cli_last_d = '1' then
                     tx_state_r <= IDLE_ST;
                  end if;
               end if;
         end case;

         if rst_i = '1' then
            tx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp_tx;

   -- Connect output signals
   tx_phy_valid_o <= tx_phy_valid;
   tx_phy_data_o  <= tx_phy_data;
   tx_phy_last_o  <= tx_phy_last;
   tx_phy_bytes_o <= tx_phy_bytes;
   debug_o        <= debug;

end Structural;

