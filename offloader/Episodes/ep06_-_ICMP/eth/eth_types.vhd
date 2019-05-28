library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

package eth_types_package is

   -- Ethernet frame decoding.
   subtype R_MAC_DST   is natural range 59*8+7 downto 54*8;   -- MAC destination                (6 bytes)
   subtype R_MAC_SRC   is natural range 53*8+7 downto 48*8;   -- MAC source                     (6 bytes)
   subtype R_MAC_TLEN  is natural range 47*8+7 downto 46*8;   -- MAC Type/Length                (2 bytes)

   subtype R_ARP_HDR   is natural range 45*8+7 downto 38*8;   -- ARP header                     (8 bytes)
   subtype R_ARP_SHA   is natural range 37*8+7 downto 32*8;   -- ARP source hardware address    (6 bytes)
   subtype R_ARP_SPA   is natural range 31*8+7 downto 28*8;   -- ARP source protocol address    (4 bytes)
   subtype R_ARP_THA   is natural range 27*8+7 downto 22*8;   -- ARP target hardware address    (6 bytes)
   subtype R_ARP_TPA   is natural range 21*8+7 downto 18*8;   -- ARP target protocol address    (4 bytes)

   subtype R_IP_VIHL   is natural range 45*8+7 downto 45*8;   -- IP version/IHL                 (1 byte)
   subtype R_IP_DSCP   is natural range 44*8+7 downto 44*8;   -- IP type of service             (1 byte)
   subtype R_IP_LEN    is natural range 43*8+7 downto 42*8;   -- IP length                      (2 bytes)
   subtype R_IP_ID     is natural range 41*8+7 downto 40*8;   -- IP identification              (2 bytes)
   subtype R_IP_FRAG   is natural range 39*8+7 downto 38*8;   -- IP flags and offset            (2 bytes)
   subtype R_IP_TTL    is natural range 37*8+7 downto 37*8;   -- IP time to live                (1 byte)
   subtype R_IP_PROT   is natural range 36*8+7 downto 36*8;   -- IP protocol                    (1 byte)
   subtype R_IP_CSUM   is natural range 35*8+7 downto 34*8;   -- IP header checksum             (2 bytes)
   subtype R_IP_SRC    is natural range 33*8+7 downto 30*8;   -- IP source address              (4 bytes)
   subtype R_IP_DST    is natural range 29*8+7 downto 26*8;   -- IP destination address         (4 bytes)
   subtype R_IP_HDR    is natural range 45*8+7 downto 26*8;   -- IP header                      (20 bytes)

   subtype R_ICMP_TC   is natural range 25*8+7 downto 24*8;   -- ICMP type & code               (2 bytes)
   subtype R_ICMP_CSUM is natural range 23*8+7 downto 22*8;   -- ICMP checksum                  (2 bytes)
   subtype R_ICMP_ID   is natural range 21*8+7 downto 20*8;   -- ICMP identifier                (2 bytes)
   subtype R_ICMP_SEQ  is natural range 19*8+7 downto 18*8;   -- ICMP sequence number           (2 bytes)
   subtype R_ICMP_HDR  is natural range 25*8+7 downto 18*8;   -- ICMP header                    (8 bytes)

   -- Calculate the Internet Checksum according to RFC 1071.
   function checksum(data : std_logic_vector) return std_logic_vector;

end package eth_types_package;

package body eth_types_package is

   function checksum(data : std_logic_vector) return std_logic_vector is
      variable res_v : std_logic_vector(19 downto 0) := (others => '0');
      variable val_v : std_logic_vector(15 downto 0);
   begin
      for i in 0 to data'length/16-1 loop
         val_v := data(i*16+15+data'right downto i*16+data'right);
         res_v := res_v + (X"0" & val_v);
      end loop;

      -- Handle wrap-around
      res_v := (X"0" & res_v(15 downto 0)) + (X"0000" & res_v(19 downto 16));
      return res_v(15 downto 0);
   end function checksum;

end package body eth_types_package;

