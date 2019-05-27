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
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(42*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(42*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end icmp;

architecture Structural of icmp is

   type t_state is (IDLE_ST, CHKSUM_ST);
   signal state_r : t_state := IDLE_ST;

   signal debug    : std_logic_vector(255 downto 0);

   signal tx_valid : std_logic;
   signal tx_data  : std_logic_vector(42*8-1 downto 0);
   signal tx_last  : std_logic;
   signal tx_bytes : std_logic_vector(5 downto 0);

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
         if tx_valid = '1' then
            debug <= tx_data(255 downto 0);
         end if;
         if rst_i = '1' then
            debug <= (others => '1');
         end if;         
      end if;
   end process p_debug;


   p_icmp : process (clk_i)

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
         tx_valid <= '0'; -- Default value

         case state_r is
            when IDLE_ST =>
               tx_data  <= (others => '0');
               tx_last  <= '0';
               tx_bytes <= (others => '0');
               -- Is this an ICMP echo request for our IP address?
               if rx_valid_i = '1' then
                  if rx_bytes_i = 0 and                                             -- Complete ARP header
                     rx_data_i(29*8+7 downto 27*8) = X"080045" and                  -- IPv4 packet
                     rx_data_i(18*8+7 downto 18*8) = X"01" and                      -- ICMP protocol
                     rx_data_i(11*8+7 downto  8*8) = G_MY_IP and                    -- For us
                     checksum(rx_data_i(27*8+7 downto 8*8)) = X"FFFF" and           -- IP header checksum correct
                     rx_data_i( 7*8+7 downto  6*8) = X"0800" then                   -- ICMP echo request
                     -- Ignore ICMP checksum

                     -- Build response:
                     -- MAC header
                     tx_data(41*8+7 downto 36*8) <= rx_data_i(35*8+7 downto 30*8);  -- MAC_DST
                     tx_data(35*8+7 downto 30*8) <= G_MY_MAC;                       -- MAC_SRC
                     tx_data(29*8+7 downto 28*8) <= X"0800";                        -- MAC_TYPELEN
                     -- IP header
                     tx_data(27*8+7 downto 27*8) <= X"45";                          -- IP_VIHL
                     tx_data(26*8+7 downto 26*8) <= X"00";                          -- IP_DSCP
                     tx_data(25*8+7 downto 24*8) <= X"001C";                        -- IP_LENGTH = 20+8
                     tx_data(23*8+7 downto 22*8) <= X"0000";                        -- IP_ID
                     tx_data(21*8+7 downto 20*8) <= X"0000";                        -- IP_FRAG
                     tx_data(19*8+7 downto 19*8) <= X"40";                          -- IP_TTL
                     tx_data(18*8+7 downto 18*8) <= X"01";                          -- IP_PROTOCOL = ICMP
                     tx_data(17*8+7 downto 16*8) <= X"0000";                        -- IP_CHKSUM
                     tx_data(15*8+7 downto 12*8) <= G_MY_IP;                        -- IP_SRC
                     tx_data(11*8+7 downto  8*8) <= rx_data_i(15*8+7 downto 12*8);  -- IP_DST
                     -- ICMP header
                     tx_data( 7*8+7 downto  7*8) <= X"00";                          -- ICMP_TYPE = Reply
                     tx_data( 6*8+7 downto  6*8) <= X"00";                          -- ICMP_CODE
                     tx_data( 5*8+7 downto  4*8) <= X"0000";                        -- ICMP_CHKSUM
                     tx_data( 3*8+7 downto  2*8) <= rx_data_i( 3*8+7 downto  2*8);  -- ICMP_ID
                     tx_data( 1*8+7 downto  0*8) <= rx_data_i( 1*8+7 downto  0*8);  -- ICMP_SEQNUM
                     state_r <= CHKSUM_ST;
                  end if;
               end if;

            when CHKSUM_ST =>
               -- Calculate checksum of IP header
               tx_data(17*8+7 downto 16*8) <= not checksum(tx_data(27*8+7 downto 8*8));

               -- Calculate checksum of ICMP header
               tx_data( 5*8+7 downto  4*8) <= not checksum(tx_data(7*8+7 downto 0*8));

               -- Send packet to host
               tx_last  <= '1';
               tx_valid <= '1';
               state_r <= IDLE_ST;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_icmp;


   -- Connect output signals
   debug_o <= debug;

   tx_valid_o <= tx_valid;
   tx_data_o  <= tx_data;
   tx_last_o  <= tx_last;
   tx_bytes_o <= tx_bytes;

end Structural;

