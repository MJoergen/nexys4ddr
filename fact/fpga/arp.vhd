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


end Structural;

