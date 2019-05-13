library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module filters for incoming ARP request for our specific IP address
-- and responds with a corresponding ARP reply.

-- ARP request
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
--
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
--  9 : THA[47 downto 40]           (Ignored)
--  8 : THA[39 downto 32]
--  7 : THA[31 downto 24]
--  6 : THA[23 downto 16]
--  5 : THA[15 downto  8]
--  4 : THA[ 7 downto  0]           (Our IP address)
--  3 : TPA[31 downto 24]
--  2 : TPA[23 downto 16]
--  1 : TPA[15 downto  8]
--  0 : TPA[ 7 downto  0]

entity arp is
   generic (
      G_MAC       : std_logic_vector(47 downto 0);
      G_IP        : std_logic_vector(31 downto 0)
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;

      -- Receive interface
      rx_valid_i  : in  std_logic;
      rx_sof_i    : in  std_logic;
      rx_eof_i    : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);

      -- Transmit interface
      tx_valid_o  : out std_logic;
      tx_sof_o    : out std_logic;
      tx_eof_o    : out std_logic;
      tx_data_o   : out std_logic_vector(7 downto 0)
   );
end arp;

architecture Structural of arp is

   constant C_ARP_SIZE : integer := 14 + 28; -- MAC + ARP

   signal hdr_valid_s : std_logic;
   signal hdr_data_s  : std_logic_vector(C_ARP_SIZE*8-1 downto 0);
   signal hdr_size_s  : std_logic_vector(7 downto 0);

   signal pl_valid_r  : std_logic;
   signal pl_data_r   : std_logic_vector(C_ARP_SIZE*8-1 downto 0);

begin

   i_ser2par : entity work.ser2par
      generic map (
         G_HDR_SIZE => C_ARP_SIZE
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         rx_valid_i  => rx_valid_i,
         rx_sof_i    => rx_sof_i,
         rx_eof_i    => rx_eof_i,
         rx_data_i   => rx_data_i,
         hdr_valid_o => hdr_valid_s,
         hdr_data_o  => hdr_data_s,
         hdr_size_o  => hdr_size_s,
         hdr_more_o  => open,             -- Ignore any extra data bytes
         pl_valid_o  => open, 
         pl_sof_o    => open, 
         pl_eof_o    => open, 
         pl_data_o   => open 
      ); -- ser2par

   p_check : process (clk_i)
      variable sha_v : std_logic_vector(47 downto 0);
      variable spa_v : std_logic_vector(31 downto 0);
   begin
      if rising_edge(clk_i) then
         pl_valid_r <= '0';

         if hdr_valid_s = '1' then
            if hdr_size_s = C_ARP_SIZE then
               if hdr_data_s(29*8+7 downto 20*8) = X"08060001080006040001" then
                  sha_v := hdr_data_s(19*8+7 downto 14*8);
                  spa_v := hdr_data_s(13*8+7 downto 10*8);
                  pl_data_r  <= sha_v & G_MAC & X"0806" &
                                X"0001080006040002" &
                                G_MAC & G_IP & sha_v & spa_v;
                  pl_valid_r <= '1';
               end if;
            end if;
         end if;
      end if;
   end process p_check;

   i_par2ser : entity work.par2ser
      generic map (
         G_PL_SIZE => C_ARP_SIZE
      )
      port map (
         clk_i       => clk_i,
         rst_i       => rst_i,
         pl_valid_i  => pl_valid_r,
         pl_data_i   => pl_data_r,
         pl_size_i   => to_std_logic_vector(C_ARP_SIZE, 8),
         tx_valid_o  => tx_valid_o,
         tx_sof_o    => tx_sof_o,
         tx_eof_o    => tx_eof_o,
         tx_data_o   => tx_data_o
      ); -- par2ser

end Structural;

