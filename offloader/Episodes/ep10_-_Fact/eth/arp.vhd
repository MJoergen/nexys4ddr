library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to ARP messages.

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

entity arp is
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
end arp;

architecture Structural of arp is

   -- Set the default value to all ones, so it's clear when the first response is sent.
   signal debug    : std_logic_vector(255 downto 0) := (others => '1');

   signal tx_valid : std_logic;
   signal tx_data  : std_logic_vector(60*8-1 downto 0);
   signal tx_last  : std_logic;
   signal tx_bytes : std_logic_vector(5 downto 0);

begin

   --------------------------------------------------
   -- Process incoming frames.
   --------------------------------------------------

   p_arp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Set default value
         tx_valid <= '0';
         tx_data  <= (others => '0');
         tx_last  <= '0';
         tx_bytes <= (others => '0');

         -- Is this an ARP request for our IP address?
         if rx_valid_i = '1' and
            rx_bytes_i = 0 and                                    -- Size of frame is ...
            rx_last_i = '1' and                                   -- ... 60 bytes.
            rx_data_i(R_MAC_TLEN) = X"0806" and                   -- ARP packet
            rx_data_i(R_ARP_HDR)  = X"0001080006040001" and       -- Request ...
            rx_data_i(R_ARP_TPA)  = G_MY_IP then                  -- ... for our IP address

            -- Build response
            tx_valid            <= '1';
            tx_data(R_MAC_DST)  <= rx_data_i(R_MAC_SRC);
            tx_data(R_MAC_SRC)  <= G_MY_MAC;
            tx_data(R_MAC_TLEN) <= X"0806";
            tx_data(R_ARP_HDR)  <= X"0001080006040002";
            tx_data(R_ARP_SHA)  <= G_MY_MAC;
            tx_data(R_ARP_SPA)  <= G_MY_IP;
            tx_data(R_ARP_THA)  <= rx_data_i(R_ARP_SHA);
            tx_data(R_ARP_TPA)  <= rx_data_i(R_ARP_SPA);
            tx_last             <= '1';
            tx_bytes            <= (others => '0');               -- Frame size of 60 bytes
         end if;
      end if;
   end process p_arp;


   --------------------------------------------------
   -- Generate debug signals.
   -- This will store the ARP packet of the transmitted response
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if tx_valid = '1' then
            debug <= tx_data(R_ARP_HDR'left downto R_ARP_HDR'left-255);
         end if;
         if rst_i = '1' then
            debug <= (others => '0');
         end if;
      end if;
   end process p_debug;


   -- Connect output signals
   debug_o    <= debug;

   tx_valid_o <= tx_valid;
   tx_data_o  <= tx_data;
   tx_last_o  <= tx_last;
   tx_bytes_o <= tx_bytes;

end Structural;

