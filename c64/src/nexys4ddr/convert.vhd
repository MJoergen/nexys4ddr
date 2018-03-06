library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This converts the VGA output to Ethernet frames.

-- TODO: Read the VGA output and convert to .ppm (P6) format, see
-- https://en.wikipedia.org/wiki/Netpbm_format Use a simple run-length encoding
-- during transfer.  Optionally, convert to png.
-- After that, use 'convert' to make a movie, see
-- http://www.andrewnoske.com/wiki/Convert_an_image_sequence_to_a_movie

entity convert is

   port (
      vga_clk_i    : in  std_logic;
      vga_rst_i    : in  std_logic;
      vga_col_i    : in  std_logic_vector(7 downto 0);
      vga_hs_i     : in  std_logic;
      vga_vs_i     : in  std_logic;
      vga_hcount_i : in  std_logic_vector(10 downto 0);
      vga_vcount_i : in  std_logic_vector(10 downto 0);

      eth_clk_i    : in  std_logic;
      eth_rst_i    : in  std_logic;
      eth_data_o   : out std_logic_vector(7 downto 0);
      eth_sof_o    : out std_logic;
      eth_eof_o    : out std_logic;
      eth_empty_o  : out std_logic;
      eth_rden_i   : in  std_logic
   );
end convert;

architecture Structural of convert is

   -- VGA input
   signal vga_ena    : std_logic := '0';
   signal vga_sof    : std_logic;
   signal vga_eof    : std_logic;
   signal vga_data   : std_logic_vector(7 downto 0);
 
   -- Compressed data
   signal vga_comp_ena    : std_logic := '0';
   signal vga_comp_sof    : std_logic;
   signal vga_comp_eof    : std_logic;
   signal vga_comp_data   : std_logic_vector(7 downto 0);
 
   -- Ethernet output
   signal eth_data  : std_logic_vector(7 downto 0) := X"AE";
   signal eth_sof   : std_logic := '1';
   signal eth_eof   : std_logic := '1';
   signal eth_empty : std_logic := '0';
   signal eth_rden  : std_logic := '0';

   signal vga_ready : std_logic := '0';

begin

   ------------------------------
   -- Transmit VGA data
   ------------------------------

   proc_tx_vga : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_data  <= vga_col_i;
         vga_sof   <= '0';
         vga_eof   <= '0';
         vga_ena   <= '0';

         if vga_vcount_i(0) = '0' and vga_hcount_i = 0 then
            vga_sof <= '1';
         end if;
         if vga_vcount_i(0) = '1' and vga_hcount_i = 639 then
            vga_eof <= '1';
            vga_ready <= '1';
         end if;
         if (vga_vcount_i(0) >= '0' and vga_vcount_i(0) <= '1') and 
            (vga_hcount_i >= 0 and vga_hcount_i <= 639 and
            vga_ready = '1') then
            vga_ena <= '1';
         end if;

         if vga_rst_i = '1' then
            vga_sof   <= '0';
            vga_eof   <= '0';
            vga_ena   <= '0';
            vga_ready <= '0';
         end if;
      end if;
   end process proc_tx_vga;

   inst_compress : entity work.compress
   port map (
      clk_i       => vga_clk_i,
      rst_i       => vga_rst_i,
      in_ena_i    => vga_ena,
      in_sof_i    => vga_sof,
      in_eof_i    => vga_eof,
      in_data_i   => vga_data,
      out_ena_o   => vga_comp_ena,
      out_sof_o   => vga_comp_sof,
      out_eof_o   => vga_comp_eof,
      out_data_o  => vga_comp_data
   );

   inst_encap : entity work.encap
   port map (
      pl_clk_i       => vga_clk_i,
      pl_rst_i       => vga_rst_i,
      pl_ena_i       => vga_comp_ena,
      pl_sof_i       => vga_comp_sof,
      pl_eof_i       => vga_comp_eof,
      pl_data_i      => vga_comp_data,
      ctrl_mac_dst_i => X"F46D04D7F3CA",
      ctrl_mac_src_i => X"F46D04112233",
      ctrl_ip_dst_i  => X"C0A8012B",
      ctrl_ip_src_i  => X"C0A8012E",
      ctrl_udp_dst_i => X"1234",
      ctrl_udp_src_i => X"2345",
      mac_clk_i      => eth_clk_i,
      mac_rst_i      => eth_rst_i,
      mac_data_o     => eth_data_o,
      mac_sof_o      => eth_sof_o,
      mac_eof_o      => eth_eof_o,
      mac_empty_o    => eth_empty_o,
      mac_rden_i     => eth_rden_i
   );

end Structural;

