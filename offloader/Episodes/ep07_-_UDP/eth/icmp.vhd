library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to ICMP messages.

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

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
      rx_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end icmp;

architecture Structural of icmp is

   type t_state is (IDLE_ST, CHKSUM_ST);
   signal state_r : t_state := IDLE_ST;

   -- Set the default value to all ones, so it's clear when the first response is sent.
   signal debug    : std_logic_vector(255 downto 0);

   signal tx_valid : std_logic;
   signal tx_data  : std_logic_vector(60*8-1 downto 0);
   signal tx_last  : std_logic;
   signal tx_bytes : std_logic_vector(5 downto 0);

begin

   --------------------------------------------------
   -- Process incoming frames.
   --------------------------------------------------

   p_icmp : process (clk_i)
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
                  if rx_data_i(R_MAC_TLEN) = X"0800" and                   -- IP packet
                     rx_data_i(R_IP_VIHL)  = X"45" and                     -- IPv4
                     rx_data_i(R_IP_PROT)  = X"01" and                     -- ICMP
                     rx_data_i(R_IP_DST)   = G_MY_IP and                   -- For us
                     checksum(rx_data_i(R_IP_HDR)) = X"FFFF" and           -- IP header checksum correct
                     rx_data_i(R_ICMP_TC)  = X"0800" then                  -- ICMP echo request

                     -- Build response
                     tx_data(R_MAC_DST)   <= rx_data_i(R_MAC_SRC);
                     tx_data(R_MAC_SRC)   <= G_MY_MAC;
                     tx_data(R_MAC_TLEN)  <= X"0800";
                     tx_data(R_IP_VIHL)   <= X"45";
                     tx_data(R_IP_DSCP)   <= X"00";
                     tx_data(R_IP_LEN)    <= X"001C";
                     tx_data(R_IP_ID)     <= X"0000";
                     tx_data(R_IP_FRAG)   <= X"0000";
                     tx_data(R_IP_TTL)    <= X"40";
                     tx_data(R_IP_PROT)   <= X"01";
                     tx_data(R_IP_CSUM)   <= X"0000";
                     tx_data(R_IP_SRC)    <= G_MY_IP;
                     tx_data(R_IP_DST)    <= rx_data_i(R_IP_SRC);
                     tx_data(R_ICMP_TC)   <= X"0000";
                     tx_data(R_ICMP_CSUM) <= X"0000";
                     tx_data(R_ICMP_ID)   <= rx_data_i(R_ICMP_ID);
                     tx_data(R_ICMP_SEQ)  <= rx_data_i(R_ICMP_SEQ);

                     state_r <= CHKSUM_ST;
                  end if;
               end if;

            when CHKSUM_ST =>
               -- Calculate checksum of IP header
               tx_data(R_IP_CSUM)   <= not checksum(tx_data(R_IP_HDR));

               -- Calculate checksum of ICMP header
               tx_data(R_ICMP_CSUM) <= not checksum(tx_data(R_ICMP_HDR));

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


   -- Connect output signals
   debug_o <= debug;

   tx_valid_o <= tx_valid;
   tx_data_o  <= tx_data;
   tx_last_o  <= tx_last;
   tx_bytes_o <= tx_bytes;

end Structural;

