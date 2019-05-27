library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to ARP messages.

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
      rx_data_i  : in  std_logic_vector(42*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(42*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end arp;

architecture Structural of arp is

   signal debug    : std_logic_vector(255 downto 0);

   signal tx_valid : std_logic;
   signal tx_data  : std_logic_vector(42*8-1 downto 0);

   -- The format of a MAC+ARP frame is as follows:
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
   -- 29 : TYPE_LEN[15 downto 8]  = 08 (ARP)
   -- 28 : TYPE_LEN[ 7 downto 0]  = 06
   -- 27 : HTYPE[15 downto 8] = 00     (Ethernet)
   -- 26 : HTYPE[ 7 downto 0] = 01
   -- 25 : PTYPE[15 downto 8] = 08     (IPv4)
   -- 24 : PTYPE[ 7 downto 0] = 00
   -- 23 : HLEN[ 7 downto 0] = 06
   -- 22 : PLEN[ 7 downto 0] = 04
   -- 21 : OPER[15 downto 8] = 00      (Request)
   -- 20 : OPER[ 7 downto 0] = 01
   -- 19 : SHA[47 downto 40]
   -- 18 : SHA[39 downto 32]
   -- 17 : SHA[31 downto 24]
   -- 16 : SHA[23 downto 16]
   -- 15 : SHA[15 downto  8]
   -- 14 : SHA[ 7 downto  0]
   -- 13 : SPA[31 downto 24]
   -- 12 : SPA[23 downto 16]
   -- 11 : SPA[15 downto  8]
   -- 10 : SPA[ 7 downto  0]
   -- 09 : THA[47 downto 40]           (Ignored)
   -- 08 : THA[39 downto 32]
   -- 07 : THA[31 downto 24]
   -- 06 : THA[23 downto 16]
   -- 05 : THA[15 downto  8]
   -- 04 : THA[ 7 downto  0]           (Our IP address)
   -- 03 : TPA[31 downto 24]
   -- 02 : TPA[23 downto 16]
   -- 01 : TPA[15 downto  8]
   -- 00 : TPA[ 7 downto  0]

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


   p_arp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         tx_valid <= '0'; -- Default value
         tx_data  <= (others => '0');

         -- Is this an ARP request for our IP address?
         if rx_valid_i = '1' and
            rx_bytes_i = 0 and                                              -- Complete ARP packet
            rx_data_i(29*8+7 downto 20*8) = X"08060001080006040001" and     -- ARP request ...
            rx_data_i(3*8+7 downto 0) = G_MY_IP then                        -- ... for our IP address

            -- Build response
            tx_data(41*8+7 downto 36*8) <= rx_data_i(35*8+7 downto 30*8);  -- MAC_DST
            tx_data(35*8+7 downto 30*8) <= G_MY_MAC;                       -- MAC_SRC
            tx_data(29*8+7 downto 20*8) <= X"08060001080006040002";        -- ARP response
            tx_data(19*8+7 downto 14*8) <= G_MY_MAC;                       -- ARP_SHA
            tx_data(13*8+7 downto 10*8) <= G_MY_IP;                        -- ARP_SPA
            tx_data( 9*8+7 downto  4*8) <= rx_data_i(19*8+7 downto 14*8);  -- ARP_THA
            tx_data( 3*8+7 downto  0*8) <= rx_data_i(13*8+7 downto 10*8);  -- ARP_TPA
            tx_valid <= '1';
         end if;
      end if;
   end process p_arp;

   -- Connect output signals
   debug_o <= debug;

   tx_valid_o <= tx_valid;
   tx_data_o  <= tx_data;
   tx_last_o  <= tx_valid;
   tx_bytes_o <= (others => '0');

end Structural;

