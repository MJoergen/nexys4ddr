library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to UDP messages.

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

entity udp is
   generic (
      G_MY_MAC       : std_logic_vector(47 downto 0);
      G_MY_IP        : std_logic_vector(31 downto 0);
      G_MY_UDP       : std_logic_vector(15 downto 0)
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      debug_o        : out std_logic_vector(255 downto 0);

      -- Ingress from PHY
      rx_phy_valid_i : in  std_logic;
      rx_phy_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_phy_last_i  : in  std_logic;
      rx_phy_bytes_i : in  std_logic_vector(5 downto 0);

      -- Ingress to client
      rx_cli_valid_o : out std_logic;
      rx_cli_data_o  : out std_logic_vector(60*8-1 downto 0);
      rx_cli_last_o  : out std_logic;
      rx_cli_bytes_o : out std_logic_vector(5 downto 0);

      -- Egress from client
      tx_cli_valid_i : in  std_logic;
      tx_cli_data_i  : in  std_logic_vector(60*8-1 downto 0);
      tx_cli_last_i  : in  std_logic;
      tx_cli_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress to PHY
      tx_phy_valid_o : out std_logic;
      tx_phy_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_phy_last_o  : out std_logic;
      tx_phy_bytes_o : out std_logic_vector(5 downto 0)
   );
end udp;

architecture Structural of udp is

   -- Receive path
   type t_rx_state is (IDLE_ST, FWD_ST, LAST_ST);
   signal rx_state_r     : t_rx_state := IDLE_ST;

   signal rx_phy_data_d  : std_logic_vector(60*8-1 downto 0);
   signal rx_phy_last_d  : std_logic;
   signal rx_phy_bytes_d : std_logic_vector(5 downto 0);

   signal rx_cli_valid_r : std_logic;
   signal rx_cli_data_r  : std_logic_vector(60*8-1 downto 0);
   signal rx_cli_last_r  : std_logic;
   signal rx_cli_bytes_r : std_logic_vector(5 downto 0);

   signal tx_hdr         : std_logic_vector(60*8-1 downto 0);


   -- Transmit path
   type t_tx_state is (IDLE_ST, FWD_ST, LAST_ST);
   signal tx_state_r     : t_tx_state := IDLE_ST;

   signal debug          : std_logic_vector(255 downto 0);

   -- Delayed input from client
   signal tx_cli_data_d  : std_logic_vector(60*8-1 downto 0);
   signal tx_cli_last_d  : std_logic;
   signal tx_cli_bytes_d : std_logic_vector(5 downto 0);
   signal tx_cli_first   : std_logic;

   signal tx_phy_valid   : std_logic;
   signal tx_phy_data    : std_logic_vector(60*8-1 downto 0);
   signal tx_phy_last    : std_logic;
   signal tx_phy_bytes   : std_logic_vector(5 downto 0);
   signal tx_phy_first   : std_logic;

begin

   --------------------------------------------------
   -- Instantiate ingress state machine
   --------------------------------------------------

   p_udp_rx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Set default values
         rx_cli_valid_r <= '0';
         rx_cli_data_r  <= (others => '0');
         rx_cli_last_r  <= '0';
         rx_cli_bytes_r <= (others => '0');

         if rx_phy_valid_i = '1' then
            rx_phy_data_d  <= rx_phy_data_i;
            rx_phy_last_d  <= rx_phy_last_i;
            rx_phy_bytes_d <= rx_phy_bytes_i;
         end if;

         case rx_state_r is
            when IDLE_ST =>
               if rx_phy_valid_i = '1' then

                  assert rx_phy_bytes_i = 0; -- Don't allow frames smaller than the minimum size

                  -- Is this an UDP packet for our IP address and UDP port?
                  if rx_phy_data_i(R_MAC_TLEN) = X"0800" and
                     rx_phy_data_i(R_IP_VIHL)  = X"45" and
                     rx_phy_data_i(R_IP_PROT)  = X"11" and
                     rx_phy_data_i(R_IP_DST)   = G_MY_IP and
                     checksum(rx_phy_data_i(R_IP_HDR)) = X"FFFF" and
                     rx_phy_data_i(R_UDP_DST)  = G_MY_UDP then

                     -- Build response:
                     -- MAC header
                     tx_hdr(R_MAC_DST)  <= rx_phy_data_i(R_MAC_SRC);
                     tx_hdr(R_MAC_SRC)  <= G_MY_MAC;
                     tx_hdr(R_MAC_TLEN) <= X"0800";
                     -- IP header
                     tx_hdr(R_IP_VIHL)  <= X"45";
                     tx_hdr(R_IP_DSCP)  <= X"00";
                     tx_hdr(R_IP_LEN)   <= rx_phy_data_i(R_IP_LEN);
                     tx_hdr(R_IP_ID)    <= X"0000";
                     tx_hdr(R_IP_FRAG)  <= X"0000";
                     tx_hdr(R_IP_TTL)   <= X"40";
                     tx_hdr(R_IP_PROT)  <= X"11";
                     tx_hdr(R_IP_CSUM)  <= X"0000";
                     tx_hdr(R_IP_SRC)   <= G_MY_IP;
                     tx_hdr(R_IP_DST)   <= rx_phy_data_i(R_IP_SRC);
                     -- UDP header
                     tx_hdr(R_UDP_SRC)  <= G_MY_UDP;
                     tx_hdr(R_UDP_DST)  <= rx_phy_data_i(R_UDP_SRC);
                     tx_hdr(R_UDP_LEN)  <= rx_phy_data_i(R_UDP_LEN);
                     tx_hdr(R_UDP_CSUM) <= X"0000";

                     rx_state_r <= FWD_ST;
                     if rx_phy_last_i = '1' then
                        rx_state_r <= LAST_ST;
                     end if;
                  end if;
               end if;

            when FWD_ST =>
               if rx_phy_valid_i = '1' then
                  rx_cli_data_r(60*8-1 downto 42*8) <= rx_phy_data_d(60*8-42*8-1 downto 0);
                  rx_cli_data_r(42*8-1 downto  0*8) <= rx_phy_data_i(60*8-1 downto 60*8-42*8);
                  rx_cli_valid_r                    <= '1';

                  if rx_phy_last_i = '1' then
                     if rx_phy_bytes_i <= 42 then
                        rx_cli_bytes_r <= rx_phy_bytes_i + 60 - 42;
                        rx_cli_last_r <= '1';
                        rx_state_r <= IDLE_ST;
                     else
                        rx_state_r <= LAST_ST;
                     end if;
                  end if;
               end if;

            when LAST_ST =>
               rx_cli_data_r(60*8-1 downto 42*8) <= rx_phy_data_d(60*8-42*8-1 downto 0);
               rx_cli_data_r(42*8-1 downto  0*8) <= (others => '0');
               rx_cli_valid_r <= '1';
               rx_cli_bytes_r <= to_stdlogicvector(to_integer(tx_hdr(R_UDP_LEN)) - 8, 6);
               rx_cli_last_r  <= '1';
               rx_state_r     <= IDLE_ST;

         end case;

         if rst_i = '1' then
            rx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp_rx;


   --------------------------------------------------
   -- Instantiate egress state machine
   --------------------------------------------------

   p_udp_tx : process (clk_i)
      variable tx_phy_data_v : std_logic_vector(60*8-1 downto 0);
   begin
      if rising_edge(clk_i) then

         -- Default values
         tx_phy_valid <= '0';
         tx_phy_data  <= (others => '0');
         tx_phy_last  <= '0';
         tx_phy_bytes <= (others => '0');

         -- Input pipeline
         if tx_cli_valid_i = '1' then
            tx_cli_data_d  <= tx_cli_data_i;
            tx_cli_last_d  <= tx_cli_last_i;
            tx_cli_bytes_d <= tx_cli_bytes_i;
         end if;

         case tx_state_r is
            when IDLE_ST =>
               if tx_cli_valid_i = '1' then
                  tx_phy_valid <= '1';
                  tx_phy_data_v(60*8-1      downto 60*8-42*8) := tx_hdr(60*8-1        downto 60*8-42*8);
                  tx_phy_data_v(60*8-1-42*8 downto 0)         := tx_cli_data_i(60*8-1 downto 42*8);
                  tx_phy_data_v(R_IP_LEN)                     := ("0000000000" & tx_cli_bytes_i) + 28;
                  tx_phy_data_v(R_UDP_LEN)                    := ("0000000000" & tx_cli_bytes_i) + 8;
                  tx_phy_data_v(R_IP_CSUM)                    := not checksum(tx_phy_data_v(R_IP_HDR)); -- Calculate checksum of IP header
                  tx_phy_data  <= tx_phy_data_v;
                  tx_phy_last  <= '0';
                  tx_phy_bytes <= (others => '0'); -- 60 bytes is minimum frame size.
                  tx_state_r   <= FWD_ST;
                  if tx_cli_last_i = '1' then
                     if tx_cli_bytes_i <= 18 then
                        tx_phy_last  <= '1';
                        tx_state_r   <= IDLE_ST;
                     else
                        tx_state_r   <= LAST_ST;
                     end if;
                  end if;
               end if;

            when FWD_ST =>
               if tx_cli_valid_i = '1' then
                  tx_phy_valid <= '1';
                  tx_phy_data(60*8-1      downto 60*8-42*8) <= tx_cli_data_d(42*8-1 downto 0);
                  tx_phy_data(60*8-1-42*8 downto 0)         <= tx_cli_data_i(60*8-1 downto 42*8);
                  tx_phy_last  <= '0';
                  tx_phy_bytes <= (others => '0');

                  if tx_cli_last_i = '1' then
                     if tx_cli_bytes_i <= 18 then
                        tx_phy_last  <= '1';
                        tx_phy_bytes <= tx_cli_bytes_i + 42;
                        tx_state_r   <= IDLE_ST;
                     else
                        tx_state_r   <= LAST_ST;
                     end if;
                  end if;
               end if;

            when LAST_ST => 
               tx_phy_valid <= '1';
               tx_phy_data(60*8-1      downto 60*8-42*8) <= tx_cli_data_d(42*8-1 downto 0);
               tx_phy_data(60*8-1-42*8 downto 0)         <= (others => '0');
               tx_phy_last  <= '1';
               tx_phy_bytes <= tx_cli_bytes_d + 42 - 60;
               tx_state_r   <= IDLE_ST;

         end case;

         if rst_i = '1' then
            tx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp_tx;


   --------------------------------------------------
   -- Generate debug signals.
   -- This will store bytes 10-41 of the transmitted frame
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
        if tx_cli_valid_i = '1' and tx_cli_first = '1' then
           debug <= tx_cli_data_i(50*8-1 downto 50*8-256);
        end if;
        if tx_phy_valid = '1' and tx_phy_first = '1' then
           debug <= tx_phy_data(50*8-1 downto 50*8-256);
        end if;
        if tx_cli_valid_i = '1' then
           tx_cli_first <= tx_cli_last_i;
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



   -- Connect output signals
   rx_cli_data_o  <= rx_cli_data_r;
   rx_cli_last_o  <= rx_cli_last_r;
   rx_cli_bytes_o <= rx_cli_bytes_r;
   rx_cli_valid_o <= rx_cli_valid_r;

   tx_phy_valid_o <= tx_phy_valid;
   tx_phy_data_o  <= tx_phy_data;
   tx_phy_last_o  <= tx_phy_last;
   tx_phy_bytes_o <= tx_phy_bytes;
   debug_o        <= debug;

end Structural;

