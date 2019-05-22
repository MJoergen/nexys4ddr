library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to ICMP messages.

entity udp is
   generic (
      G_MY_MAC       : std_logic_vector(47 downto 0);
      G_MY_IP        : std_logic_vector(31 downto 0);
      G_MY_PORT      : std_logic_vector(15 downto 0)
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;

      -- Ingress from PHY
      rx_phy_data_i  : in  std_logic_vector(7 downto 0);
      rx_phy_sof_i   : in  std_logic;
      rx_phy_eof_i   : in  std_logic;
      rx_phy_valid_i : in  std_logic;

      -- Ingress to client
      rx_cli_data_o  : out std_logic_vector(7 downto 0);
      rx_cli_sof_o   : out std_logic;
      rx_cli_eof_o   : out std_logic;
      rx_cli_valid_o : out std_logic;

      -- Egress from client
      tx_cli_empty_i : in  std_logic;
      tx_cli_rden_o  : out std_logic;
      tx_cli_data_i  : in  std_logic_vector(7 downto 0);
      tx_cli_sof_i   : in  std_logic;
      tx_cli_eof_i   : in  std_logic;

      -- Egress to PHY
      tx_phy_empty_o : out std_logic;
      tx_phy_rden_i  : in  std_logic;
      tx_phy_data_o  : out std_logic_vector(7 downto 0);
      tx_phy_sof_o   : out std_logic;
      tx_phy_eof_o   : out std_logic
   );
end udp;

architecture Structural of udp is

   type t_rx_state is (IDLE_ST, FWD_ST);
   signal rx_state_r : t_rx_state := IDLE_ST;

   -- Output from byte2wide
   signal rx_hdr_valid : std_logic;
   signal rx_hdr_data  : std_logic_vector(42*8-1 downto 0);
   signal rx_hdr_size  : std_logic_vector(7 downto 0);
   signal rx_hdr_more  : std_logic;
   signal rx_pl_valid  : std_logic;
   signal rx_pl_sof    : std_logic;
   signal rx_pl_eof    : std_logic;
   signal rx_pl_data   : std_logic_vector(7 downto 0);

--   signal tx_rsp_valid : std_logic;
--   signal tx_rsp_data  : std_logic_vector(42*8-1 downto 0);

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

begin

   --------------------------------------------------
   -- Instantiate byte2wide
   --------------------------------------------------

   i_byte2wide : entity work.byte2wide
   generic map (
      G_HDR_SIZE  => 42          -- Size of ARP packet
   )
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      rx_valid_i  => rx_phy_valid_i,
      rx_sof_i    => rx_phy_sof_i,
      rx_eof_i    => rx_phy_eof_i,
      rx_data_i   => rx_phy_data_i,
      hdr_valid_o => rx_hdr_valid,
      hdr_data_o  => rx_hdr_data,
      hdr_size_o  => rx_hdr_size,
      hdr_more_o  => rx_hdr_more,
      pl_valid_o  => rx_pl_valid,
      pl_eof_o    => rx_pl_eof,
      pl_data_o   => rx_pl_data
   ); -- i_byte2wide


   p_udp : process (clk_i)

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
         report to_hstring(res_v);
         return res_v(15 downto 0);
      end function checksum;

   begin
      if rising_edge(clk_i) then

         if rx_phy_valid_i = '1' then
            rx_pl_sof <= rx_hdr_more;
         end if;

         case rx_state_r is
            when IDLE_ST =>
               -- Is this an UDP packet for our IP address and UDP port?
               if rx_hdr_valid = '1' then
                  if rx_hdr_size = 42 and                                              -- Size of UDP header
                     rx_hdr_data(29*8+7 downto 27*8) = X"080045" and                   -- IPv4 packet
                     rx_hdr_data(18*8+7 downto 18*8) = X"11" and                       -- UDP protocol
                     rx_hdr_data(11*8+7 downto  8*8) = G_MY_IP and                     -- For us
                     checksum(rx_hdr_data(27*8+7 downto 8*8)) = X"FFFF" and            -- IP header checksum correct
                     rx_hdr_data( 5*8+7 downto  4*8) = G_MY_PORT and                   -- UDP port
                     rx_hdr_more = '1' then                                            -- More data follows
                     -- Ignore UDP header checksum

                     rx_state_r <= FWD_ST;
                  end if;
               end if;

            when FWD_ST =>
               if rx_pl_valid = '1' and rx_pl_eof = '1' then
                  rx_state_r <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            rx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp;

   -- Connect signals to client
   rx_cli_data_o  <= rx_pl_data  when rx_state_r = FWD_ST else X"00";
   rx_cli_sof_o   <= rx_pl_sof   when rx_state_r = FWD_ST else '0';
   rx_cli_eof_o   <= rx_pl_eof   when rx_state_r = FWD_ST else '0';
   rx_cli_valid_o <= rx_pl_valid when rx_state_r = FWD_ST else '0';


--   --------------------------------------------------
--   -- Instantiate wide2byte
--   --------------------------------------------------
--
--   i_wide2byte : entity work.wide2byte
--   generic map (
--      G_PL_SIZE => 42            -- Size of ARP packet
--   )
--   port map (
--      clk_i      => clk_i,
--      rst_i      => rst_i,
--      pl_valid_i => tx_rsp_valid,
--      pl_data_i  => tx_rsp_data,
--      pl_size_i  => X"3C",       -- Minimum frame size is 60 bytes.
--      tx_empty_o => tx_phy_empty_o,
--      tx_rden_i  => tx_phy_rden_i,
--      tx_sof_o   => tx_phy_sof_o,
--      tx_eof_o   => tx_phy_eof_o,
--      tx_data_o  => tx_phy_data_o
--   ); -- i_wide2byte

   -- TBD
   tx_cli_rden_o  <= '0';
   tx_phy_empty_o <= '1';
   tx_phy_data_o  <= (others => '0');
   tx_phy_sof_o   <= '0';
   tx_phy_eof_o   <= '0';

end Structural;

