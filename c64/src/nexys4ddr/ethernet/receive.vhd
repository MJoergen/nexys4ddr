library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module strips the incoming frame of the MAC CRC (the last four bytes)
-- and forwards the CRC valid bit from EOF to SOF.
-- This module therefore operates in a store-and-forward mode,
-- where the entire frame is stored in the FIFO, until the last byte is received.
-- Only valid frames are forwarded. In other words, errored frames are discarded.
-- Frames are stored in a special-purpose FIFO, where the write pointer of
-- the SOF is recorded. If the frame is to be discarded, the write pointer is reset
-- to the start of the errored frame.
-- For simplicity, everything is in the same clock domain.

-- There is no flow control.

entity receive is
   port (
      -- Input interface
      eth_clk_i       : in  std_logic;
      eth_rst_i       : in  std_logic;
      eth_ena_i       : in  std_logic;
      eth_sof_i       : in  std_logic;
      eth_eof_i       : in  std_logic;
      eth_err_i       : in  std_logic;
      eth_data_i      : in  std_logic_vector(7 downto 0);
      eth_crc_valid_i : in  std_logic;    -- Only valid @ EOF

      -- Output interface
      pl_clk_i       : in  std_logic;
      pl_rst_i       : in  std_logic;
      pl_ena_o       : out std_logic;
      pl_sof_o       : out std_logic;
      pl_eof_o       : out std_logic;
      pl_data_o      : out std_logic_vector(7 downto 0)
   );
end receive;

architecture Structural of receive is

   signal eth_rx_ena  : std_logic;
   signal eth_rx_sof  : std_logic;
   signal eth_rx_eof  : std_logic;
   signal eth_rx_data : std_logic_vector(7 downto 0);

begin

   inst_strip_crc : entity work.strip_crc
   port map (
      clk_i          => eth_clk_i,
      rst_i          => eth_rst_i,
      rx_ena_i       => eth_ena_i,
      rx_sof_i       => eth_sof_i,
      rx_eof_i       => eth_eof_i,
      rx_data_i      => eth_data_i,
      rx_err_i       => eth_err_i,
      rx_crc_valid_i => eth_crc_valid_i,
      out_ena_o      => eth_rx_ena,
      out_sof_o      => eth_rx_sof,
      out_eof_o      => eth_rx_eof,
      out_data_o     => eth_rx_data     
   );


   inst_decap : entity work.decap
   port map (
      -- Ctrl interface. Assumed to be constant for now.
      ctrl_mac_dst_i  => X"F46D04D7F3CA",
      ctrl_ip_dst_i   => X"C0A8012B",      -- 192.168.1.43
      ctrl_udp_dst_i  => X"1234",          -- Port 4660

      -- Mac interface @ eth_clk_i
      mac_clk_i       => eth_clk_i,
      mac_rst_i       => eth_rst_i,
      mac_ena_i       => eth_rx_ena,
      mac_sof_i       => eth_rx_sof,
      mac_eof_i       => eth_rx_eof,
      mac_data_i      => eth_rx_data,

      -- Payload interface @ pl_clk_i
      pl_clk_i        => pl_clk_i,  
      pl_rst_i        => pl_rst_i, 
      pl_afull_i      => '0',
      pl_ena_o        => pl_ena_o,
      pl_sof_o        => pl_sof_o,
      pl_eof_o        => pl_eof_o,
      pl_data_o       => pl_data_o
   );

end Structural;

