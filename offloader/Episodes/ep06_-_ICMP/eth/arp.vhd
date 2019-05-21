library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to ARP messages.

entity arp is
   generic (
      G_MY_MAC     : std_logic_vector(47 downto 0);
      G_MY_IP      : std_logic_vector(31 downto 0)
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      debug_o      : out std_logic_vector(255 downto 0);

      -- Ingress
      rx_data_i    : in  std_logic_vector(7 downto 0);
      rx_sof_i     : in  std_logic;
      rx_eof_i     : in  std_logic;
      rx_valid_i   : in  std_logic;

      -- Egress
      tx_empty_o   : out std_logic;
      tx_rden_i    : in  std_logic;
      tx_data_o    : out std_logic_vector(7 downto 0);
      tx_sof_o     : out std_logic;
      tx_eof_o     : out std_logic
   );
end arp;

architecture Structural of arp is

   signal debug        : std_logic_vector(255 downto 0);

   -- Output from byte2wide
   signal hdr_valid    : std_logic;
   signal hdr_data     : std_logic_vector(42*8-1 downto 0);
   signal hdr_size     : std_logic_vector(7 downto 0);

   signal rsp_valid    : std_logic;
   signal rsp_data     : std_logic_vector(42*8-1 downto 0);

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
   begin
      if rising_edge(clk_i) then
         rsp_valid <= '0'; -- Default value

         -- Is this an ARP request for our IP address?
         if hdr_valid = '1' and
            hdr_size = 42 and                                              -- Size of ARP packet
            hdr_data(29*8+7 downto 20*8) = X"08060001080006040001" and     -- ARP request ...
            hdr_data(3*8+7 downto 0) = G_MY_IP then                        -- ... for our IP address
            -- Build response
            rsp_data(41*8+7 downto 36*8) <= hdr_data(35*8+7 downto 30*8);  -- MAC_DST
            rsp_data(35*8+7 downto 30*8) <= G_MY_MAC;                      -- MAC_SRC
            rsp_data(29*8+7 downto 20*8) <= X"08060001080006040002";       -- ARP response
            rsp_data(19*8+7 downto 14*8) <= G_MY_MAC;                      -- ARP_SHA
            rsp_data(13*8+7 downto 10*8) <= G_MY_IP;                       -- ARP_SPA
            rsp_data( 9*8+7 downto  4*8) <= hdr_data(19*8+7 downto 14*8);  -- ARP_THA
            rsp_data( 3*8+7 downto  0*8) <= hdr_data(13*8+7 downto 10*8);  -- ARP_TPA
            rsp_valid <= '1';
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

