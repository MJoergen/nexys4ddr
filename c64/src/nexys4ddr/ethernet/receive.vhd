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
   generic (
      G_DUT_MAC  : std_logic_vector(47 downto 0);
      G_DUT_IP   : std_logic_vector(31 downto 0);
      G_DUT_PORT : std_logic_vector(15 downto 0)
   );
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
      pl_wr_addr_o   : out std_logic_vector(15 downto 0);
      pl_wr_en_o     : out std_logic;
      pl_wr_data_o   : out std_logic_vector(7 downto 0);
      pl_reset_o     : out std_logic;
      pl_drop_mac_o  : out std_logic;
      pl_drop_ip_o   : out std_logic;
      pl_drop_udp_o  : out std_logic
   );
end receive;

architecture Structural of receive is

   signal eth_rx_ena  : std_logic;
   signal eth_rx_sof  : std_logic;
   signal eth_rx_eof  : std_logic;
   signal eth_rx_data : std_logic_vector(7 downto 0);

   signal pl_ena  : std_logic;
   signal pl_sof  : std_logic;
   signal pl_eof  : std_logic;
   signal pl_data : std_logic_vector(7 downto 0);

   signal pl_cnt       : std_logic_vector(1 downto 0);
   signal pl_reset     : std_logic_vector(7 downto 0);
   signal pl_wr_addr   : std_logic_vector(15 downto 0);
   signal pl_wr_addr_d : std_logic_vector(15 downto 0);
   signal pl_wr_en     : std_logic;
   signal pl_wr_data   : std_logic_vector(7 downto 0);

   signal pl_drop_mac : std_logic;
   signal pl_drop_ip  : std_logic;
   signal pl_drop_udp : std_logic;

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
      ctrl_mac_dst_i  => G_DUT_MAC,
      ctrl_ip_dst_i   => G_DUT_IP,
      ctrl_udp_dst_i  => G_DUT_PORT,

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
      pl_ena_o        => pl_ena,
      pl_sof_o        => pl_sof,
      pl_eof_o        => pl_eof,
      pl_data_o       => pl_data,
      pl_drop_mac_o   => pl_drop_mac,
      pl_drop_ip_o    => pl_drop_ip,
      pl_drop_udp_o   => pl_drop_udp
   );


   -- Convert packet to memory accesses.
   -- First two bytes are address (in little-endian format)
   process (pl_clk_i)
   begin
      if rising_edge(pl_clk_i) then
         pl_wr_en <= '0';

         if pl_ena = '1' then
            case pl_cnt is
               when "00" => 
                  if pl_sof = '1' then
                     pl_wr_addr( 7 downto 0) <= pl_data;
                     pl_cnt <= "01";
                  end if;

               when "01" => 
                  pl_wr_addr(15 downto 8) <= pl_data;
                  pl_cnt <= "10";

               when "10" => 
                  pl_reset <= pl_data;
                  pl_cnt <= "11";

               when "11" => 
                  pl_wr_en     <= '1';
                  pl_wr_data   <= pl_data;
                  pl_wr_addr   <= pl_wr_addr + 1;
                  pl_wr_addr_d <= pl_wr_addr;

                  if pl_eof = '1' then
                     pl_reset(0) <= pl_reset(1);
                     pl_cnt <= "00";
                  end if;

               when others =>
                  null;
            end case;
         end if;

         if pl_rst_i = '1' then
            pl_reset <= (others => '0');
            pl_cnt <= "00";
         end if;
      end if;
   end process;


   -- Drive output signals
   pl_wr_addr_o  <= pl_wr_addr_d;
   pl_wr_en_o    <= pl_wr_en;
   pl_wr_data_o  <= pl_wr_data;
   pl_reset_o    <= pl_reset(0);
   pl_drop_mac_o <= pl_drop_mac;
   pl_drop_ip_o  <= pl_drop_ip;
   pl_drop_udp_o <= pl_drop_udp;

end Structural;

