library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to ICMP messages.

entity icmp is
   generic (
      G_MY_MAC   : std_logic_vector(47 downto 0);
      G_MY_IP    : std_logic_vector(31 downto 0)
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      debug_o    : out std_logic_vector(255 downto 0);

      -- Ingress
      rx_data_i  : in  std_logic_vector(7 downto 0);
      rx_sof_i   : in  std_logic;
      rx_eof_i   : in  std_logic;
      rx_valid_i : in  std_logic;

      -- Egress
      tx_empty_o : out std_logic;
      tx_rden_i  : in  std_logic;
      tx_data_o  : out std_logic_vector(7 downto 0);
      tx_sof_o   : out std_logic;
      tx_eof_o   : out std_logic
   );
end icmp;

architecture Structural of icmp is

   type t_state is (IDLE_ST, CHKSUM_ST);
   signal state_r : t_state := IDLE_ST;

   signal debug        : std_logic_vector(255 downto 0);

   -- Output from byte2wide
   signal hdr_valid    : std_logic;
   signal hdr_data     : std_logic_vector(42*8-1 downto 0);
   signal hdr_size     : std_logic_vector(7 downto 0);

   signal rsp_valid    : std_logic;
   signal rsp_data     : std_logic_vector(42*8-1 downto 0);

   -- The format of a MAC+IP+ICMP frame is as follows:
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
   -- 07 : ICMP_TYPE                   = 08 (Echo request)
   -- 06 : ICMP_CODE                   = 00
   -- 05 : ICMP_CHKSUM[15 downto 8]
   -- 04 : ICMP_CHKSUM[ 7 downto 0]
   -- 03 : ICMP_ID[15 downto 8]
   -- 02 : ICMP_ID[ 7 downto 0]
   -- 01 : ICMP_SEQNUM[15 downto 8]
   -- 00 : ICMP_SEQNUM[ 7 downto 0]

begin

   --------------------------------------------------
   -- Generate debug signals.
   -- This will store bytes 10-41 of the received frame.
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rsp_valid = '1' then
            debug <= rsp_data(255 downto 0);
         end if;
         if rst_i = '1' then
            debug <= (others => '1');
         end if;         
      end if;
   end process p_debug;


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
      rx_valid_i  => rx_valid_i,
      rx_sof_i    => rx_sof_i,
      rx_eof_i    => rx_eof_i,
      rx_data_i   => rx_data_i,
      hdr_valid_o => hdr_valid,
      hdr_data_o  => hdr_data,
      hdr_size_o  => hdr_size,
      hdr_more_o  => open,       -- Not used
      pl_valid_o  => open,       -- Not used
      pl_eof_o    => open,       -- Not used
      pl_data_o   => open        -- Not used
   ); -- i_byte2wide


   p_arp : process (clk_i)

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
      if rising_edge(clk_i) then
         rsp_valid <= '0'; -- Default value

         case state_r is
            when IDLE_ST =>
               -- Is this an ICMP echo request for our IP address?
               if hdr_valid = '1' then
                  if hdr_size = 42 and                                              -- Size of ARP packet
                     hdr_data(29*8+7 downto 27*8) = X"080045" and                   -- IPv4 packet
                     hdr_data(18*8+7 downto 18*8) = X"01" and                       -- ICMP protocol
                     hdr_data(11*8+7 downto  8*8) = G_MY_IP and                     -- For us
                     checksum(hdr_data(27*8+7 downto 8*8)) = X"FFFF" and            -- IP header checksum correct
                     hdr_data( 7*8+7 downto  6*8) = X"0800" and                     -- ICMP echo request
                     checksum(hdr_data(7*8+7 downto 0*8)) = X"FFFF" then            -- ICMP header checksum correct

                     -- Build response:
                     -- MAC header
                     rsp_data(41*8+7 downto 36*8) <= hdr_data(35*8+7 downto 30*8);  -- MAC_DST
                     rsp_data(35*8+7 downto 30*8) <= G_MY_MAC;                      -- MAC_SRC
                     rsp_data(29*8+7 downto 28*8) <= X"0800";                       -- MAC_TYPELEN
                     -- IP header
                     rsp_data(27*8+7 downto 27*8) <= X"45";                         -- IP_VIHL
                     rsp_data(26*8+7 downto 26*8) <= X"00";                         -- IP_DSCP
                     rsp_data(25*8+7 downto 24*8) <= X"001C";                       -- IP_LENGTH = 20+8
                     rsp_data(23*8+7 downto 22*8) <= X"0000";                       -- IP_ID
                     rsp_data(21*8+7 downto 20*8) <= X"0000";                       -- IP_FRAG
                     rsp_data(19*8+7 downto 19*8) <= X"40";                         -- IP_TTL
                     rsp_data(18*8+7 downto 18*8) <= X"01";                         -- IP_PROTOCOL = ICMP
                     rsp_data(17*8+7 downto 16*8) <= X"0000";                       -- IP_CHKSUM
                     rsp_data(15*8+7 downto 12*8) <= G_MY_IP;                       -- IP_SRC
                     rsp_data(11*8+7 downto  8*8) <= hdr_data(15*8+7 downto 12*8);  -- IP_DST
                     -- ICMP header
                     rsp_data( 7*8+7 downto  7*8) <= X"00";                         -- ICMP_TYPE = Reply
                     rsp_data( 6*8+7 downto  6*8) <= X"00";                         -- ICMP_CODE
                     rsp_data( 5*8+7 downto  4*8) <= X"0000";                       -- ICMP_CHKSUM
                     rsp_data( 3*8+7 downto  2*8) <= hdr_data( 3*8+7 downto  2*8);  -- ICMP_ID
                     rsp_data( 1*8+7 downto  0*8) <= hdr_data( 1*8+7 downto  0*8);  -- ICMP_SEQNUM
                     state_r <= CHKSUM_ST;
                  end if;
               end if;

            when CHKSUM_ST =>
               -- Calculate checksum of IP header
               rsp_data(17*8+7 downto 16*8) <= not checksum(hdr_data(27*8+7 downto 8*8));

               -- Calculate checksum of ICMP header
               rsp_data( 5*8+7 downto  4*8) <= not checksum(hdr_data(7*8+7 downto 0*8));

               -- Send packet to host
               rsp_valid <= '1';
               state_r <= IDLE_ST;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_arp;


   --------------------------------------------------
   -- Instantiate wide2byte
   --------------------------------------------------

   i_wide2byte : entity work.wide2byte
   generic map (
      G_PL_SIZE => 42            -- Size of ARP packet
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      pl_valid_i => rsp_valid,
      pl_data_i  => rsp_data,
      pl_size_i  => X"3C",       -- Minimum frame size is 60 bytes.
      tx_empty_o => tx_empty_o,
      tx_rden_i  => tx_rden_i,
      tx_sof_o   => tx_sof_o,
      tx_eof_o   => tx_eof_o,
      tx_data_o  => tx_data_o
   ); -- i_wide2byte


   -- Connect output signals
   debug_o <= debug;

end Structural;

