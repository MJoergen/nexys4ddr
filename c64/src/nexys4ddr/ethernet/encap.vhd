library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity encap is
   port (
      clk50_i    : in  std_logic;        -- Must be 50 MHz
      rst_i      : in  std_logic;

      -- Ctrl interface
      ctrl_mac_dst_i : in std_logic_vector(47 downto 0);
      ctrl_mac_src_i : in std_logic_vector(47 downto 0);
      ctrl_ip_dst_i  : in std_logic_vector(31 downto 0);
      ctrl_ip_src_i  : in std_logic_vector(31 downto 0);
      ctrl_udp_dst_i : in std_logic_vector(15 downto 0);
      ctrl_udp_src_i : in std_logic_vector(15 downto 0);

      -- Payload interface
      tx_ena_i   : in  std_logic;
      tx_sof_i   : in  std_logic;
      tx_eof_i   : in  std_logic;
      tx_data_i  : in  std_logic_vector(7 downto 0);

      -- Mac interface
      mac_data_o  : out std_logic_vector(7 downto 0);
      mac_sof_o   : out std_logic;
      mac_eof_o   : out std_logic;
      mac_empty_o : out std_logic;
      mac_rden_i  : in  std_logic
   );
end encap;

architecture Structural of encap is

begin


end Structural;

