library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

package eth_types_package is

   -- Ethernet frame decoding.
   subtype R_MAC_DST  is natural range 59*8+7 downto 54*8;   -- MAC destination                (6 bytes)
   subtype R_MAC_SRC  is natural range 53*8+7 downto 48*8;   -- MAC source                     (6 bytes)
   subtype R_MAC_TLEN is natural range 47*8+7 downto 46*8;   -- MAC Type/Length                (2 bytes)

   subtype R_ARP_HDR  is natural range 45*8+7 downto 38*8;   -- ARP header                     (8 bytes)
   subtype R_ARP_SHA  is natural range 37*8+7 downto 32*8;   -- ARP source hardware address    (6 bytes)
   subtype R_ARP_SPA  is natural range 31*8+7 downto 28*8;   -- ARP source protocol address    (4 bytes)
   subtype R_ARP_THA  is natural range 27*8+7 downto 22*8;   -- ARP target hardware address    (6 bytes)
   subtype R_ARP_TPA  is natural range 21*8+7 downto 18*8;   -- ARP target protocol address    (4 bytes)

end package eth_types_package;

package body eth_types_package is
end package body eth_types_package;

