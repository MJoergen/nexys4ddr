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

   generic (
      G_DUT_MAC   : std_logic_vector(47 downto 0);
      G_DUT_IP    : std_logic_vector(31 downto 0);
      G_DUT_PORT  : std_logic_vector(15 downto 0);
      G_HOST_MAC  : std_logic_vector(47 downto 0);
      G_HOST_IP   : std_logic_vector(31 downto 0);
      G_HOST_PORT : std_logic_vector(15 downto 0)
   );
   port (
      vga_clk_i      : in  std_logic;
      vga_rst_i      : in  std_logic;
      vga_col_i      : in  std_logic_vector(7 downto 0);
      vga_hs_i       : in  std_logic;    -- Not used
      vga_vs_i       : in  std_logic;    -- Not used
      vga_hcount_i   : in  std_logic_vector(10 downto 0);
      vga_vcount_i   : in  std_logic_vector(10 downto 0);
      vga_transmit_i : in  std_logic;

      eth_clk_i      : in  std_logic;
      eth_rst_i      : in  std_logic;
      eth_data_o     : out std_logic_vector(7 downto 0);
      eth_sof_o      : out std_logic;
      eth_eof_o      : out std_logic;
      eth_empty_o    : out std_logic;
      eth_rden_i     : in  std_logic;

      fifo_error_o   : out std_logic
   );
end convert;

architecture Structural of convert is

   -- Packet with VGA data
   signal vga_transmit : std_logic := '0';
   signal vga_ena      : std_logic := '0';
   signal vga_sof      : std_logic;
   signal vga_eof      : std_logic;
   signal vga_data     : std_logic_vector(7 downto 0);
   signal vga_line     : std_logic_vector(7 downto 0);  -- Valid at SOF

   -- Pipeline
   signal vga_ena_d  : std_logic := '0';
   signal vga_sof_d  : std_logic;
   signal vga_eof_d  : std_logic;
   signal vga_data_d : std_logic_vector(7 downto 0);
 
   -- Packet with VGA data, including VGA line number
   signal vga_pkg_ena  : std_logic := '0';
   signal vga_pkg_sof  : std_logic;
   signal vga_pkg_eof  : std_logic;
   signal vga_pkg_data : std_logic_vector(7 downto 0);
 
   -- Compressed data
   signal vga_comp_ena  : std_logic := '0';
   signal vga_comp_sof  : std_logic;
   signal vga_comp_eof  : std_logic;
   signal vga_comp_data : std_logic_vector(7 downto 0);
 
   -- Output to MAC
   signal eth_data  : std_logic_vector(7 downto 0) := X"AE";
   signal eth_sof   : std_logic := '1';
   signal eth_eof   : std_logic := '1';
   signal eth_empty : std_logic := '0';
   signal eth_rden  : std_logic := '0';

begin

   -----------------------------------------------
   -- Generate packet with color data for 8 lines.
   -- Total of 640*8 = 5120 bytes.
   ------------------.----------------------------

   proc_packet : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_ena  <= '0';
         vga_sof  <= '0';
         vga_eof  <= '0';
         vga_data <= vga_col_i;
         vga_line <= vga_vcount_i(10 downto 3);

         if (vga_vcount_i >= 0 and vga_vcount_i <= 479) and
            (vga_hcount_i >= 0 and vga_hcount_i <= 639) and
            vga_transmit = '1' then

            vga_ena <= '1';
            if vga_vcount_i(2 downto 0) = "000" and vga_hcount_i = 0 then
               vga_sof <= '1';
            end if;
            if vga_vcount_i(2 downto 0) = "111" and vga_hcount_i = 639 then
               vga_eof <= '1';
            end if;
         end if;

         -- Only sample 'transmit' at end of a frame
         if (vga_vcount_i >= 480) then
            vga_transmit <= vga_transmit_i;
         end if;

         if vga_rst_i = '1' then
            vga_ena <= '0';
            vga_sof <= '0';
            vga_eof <= '0';
         end if;
      end if;
   end process proc_packet;


   -----------------------------------------------
   -- Insert VGA line number
   ------------------.----------------------------

   proc_delay : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_ena_d  <= vga_ena;
         vga_sof_d  <= vga_sof;
         vga_eof_d  <= vga_eof;
         vga_data_d <= vga_data;

         if vga_rst_i = '1' then
            vga_ena_d <= '0';
            vga_sof_d <= '0';
            vga_eof_d <= '0';
         end if;
      end if;
   end process proc_delay;

   proc_insert : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then

         if vga_ena = '1' and vga_sof = '1' then
            vga_pkg_ena  <= vga_ena;
            vga_pkg_sof  <= '1';
            vga_pkg_eof  <= vga_eof;
            vga_pkg_data <= vga_line;
         else
            vga_pkg_ena  <= vga_ena_d;
            vga_pkg_sof  <= '0';
            vga_pkg_eof  <= vga_eof_d;
            vga_pkg_data <= vga_data_d;
         end if;

         if vga_rst_i = '1' then
            vga_pkg_ena <= '0';
            vga_pkg_sof <= '0';
            vga_pkg_eof <= '0';
         end if;
      end if;
   end process proc_insert;


   ------------------------------
   -- Compress packet
   ------------------------------

   inst_compress : entity work.compress
   port map (
      clk_i       => vga_clk_i,
      rst_i       => vga_rst_i,
      in_ena_i    => vga_pkg_ena,
      in_sof_i    => vga_pkg_sof,
      in_eof_i    => vga_pkg_eof,
      in_data_i   => vga_pkg_data,
      out_ena_o   => vga_comp_ena,
      out_sof_o   => vga_comp_sof,
      out_eof_o   => vga_comp_eof,
      out_data_o  => vga_comp_data
   );


   ---------------------------------------
   -- Encapsulate packet in Ethernet frame
   ---------------------------------------

   inst_encap : entity work.encap
   port map (
      pl_clk_i       => vga_clk_i,
      pl_rst_i       => vga_rst_i,
      pl_ena_i       => vga_comp_ena,
      pl_sof_i       => vga_comp_sof,
      pl_eof_i       => vga_comp_eof,
      pl_data_i      => vga_comp_data,
      pl_error_o     => fifo_error_o,
      ctrl_mac_dst_i => G_HOST_MAC,
      ctrl_mac_src_i => G_DUT_MAC,
      ctrl_ip_dst_i  => G_HOST_IP,
      ctrl_ip_src_i  => G_DUT_IP,
      ctrl_udp_dst_i => G_HOST_PORT,
      ctrl_udp_src_i => G_DUT_PORT,
      mac_clk_i      => eth_clk_i,
      mac_rst_i      => eth_rst_i,
      mac_data_o     => eth_data_o,
      mac_sof_o      => eth_sof_o,
      mac_eof_o      => eth_eof_o,
      mac_empty_o    => eth_empty_o,
      mac_rden_i     => eth_rden_i
   );

end Structural;

