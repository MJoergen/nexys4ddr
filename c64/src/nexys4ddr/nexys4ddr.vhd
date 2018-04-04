library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level wrapper for the NEXYS4DDR board.
-- This is needed, because this design is meant to
-- work on both the BASYS2 and the NEXYS4DDR boards.
-- This file therefore contains all the stuff
-- particular to the NEXYS4DDR platform.

entity nexys4ddr is

   generic (
      G_RESET_SIZE : integer := 22;          -- Number of bits in reset counter.
      G_SIMULATION : boolean := false
   );
   port (
      -- Clock. Connected to an external 100 MHz crystal.
      clk100_i     : in    std_logic;

      -- Reset. Asserted low.
      sys_rstn_i   : in    std_logic;

      -- Input switches and push buttons
      sw_i         : in    std_logic_vector(15 downto 0);
      btn_i        : in    std_logic_vector(4 downto 0);

      -- Keyboard / mouse
      ps2_clk_i    : in    std_logic;
      ps2_data_i   : in    std_logic;

      -- Output LEDs
      led_o        : out   std_logic_vector(15 downto 0);

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic;

      -- Output to VGA monitor
      vga_hs_o     : out   std_logic;
      vga_vs_o     : out   std_logic;
      vga_col_o    : out   std_logic_vector(11 downto 0)
   );
end nexys4ddr;

architecture Structural of nexys4ddr is

   -- Clocks and Reset
   signal vga_clk   : std_logic;
   signal vga_rst   : std_logic;
   signal cpu_clk   : std_logic;
   signal cpu_rst   : std_logic;
   signal eth_clk   : std_logic;
   signal eth_rst   : std_logic;
 
   -- VGA output
   signal vga_col    : std_logic_vector(7 downto 0);
   signal vga_hs     : std_logic;
   signal vga_vs     : std_logic;
   signal vga_hcount : std_logic_vector(10 downto 0);
   signal vga_vcount : std_logic_vector(10 downto 0);
 
   -- LED output
   signal led : std_logic;

   -- Convert colour from 8-bit format to 12-bit format
   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
      type t_dat is array (natural range <>) of std_logic_vector(3 downto 0);

      constant conv2_4 : t_dat :=
         ("0000", "0101", "1010", "1111");

      constant conv3_4 : t_dat :=
         ("0000", "0010", "0100", "0110", "1001", "1011", "1101", "1111");
   begin
      return conv3_4(conv_integer(arg(7 downto 5))) &
             conv3_4(conv_integer(arg(4 downto 2))) &
             conv2_4(conv_integer(arg(1 downto 0)));
   end function col8to12;

   signal eth_tx_data  : std_logic_vector(7 downto 0);
   signal eth_tx_sof   : std_logic;
   signal eth_tx_eof   : std_logic;
   signal eth_tx_empty : std_logic;
   signal eth_tx_rden  : std_logic;

   signal eth_rx_data      : std_logic_vector(7 downto 0);
   signal eth_rx_sof       : std_logic;
   signal eth_rx_eof       : std_logic;
   signal eth_rx_en        : std_logic;
   signal eth_rx_err       : std_logic;
   signal eth_rx_crc_valid : std_logic;

   signal eth_smi_ready    : std_logic;
   constant eth_smi_phy    : std_logic_vector(4 downto 0) := "00001";
   signal eth_smi_addr     : std_logic_vector(4 downto 0);
   signal eth_smi_rden     : std_logic;
   signal eth_smi_data_out : std_logic_vector(15 downto 0);
   signal eth_smi_wren     : std_logic;
   signal eth_smi_data_in  : std_logic_vector(15 downto 0);

   signal eth_smi_registers : std_logic_vector(32*16-1 downto 0);
   signal dat               : std_logic_vector(8*16-1 downto 0);
   signal eth_debug         : std_logic_vector(32*16-1 downto 0);

   signal fifo_error : std_logic;

   -- Payload interface @ cpu_clk
   signal cpu_pl_ena   : std_logic;
   signal cpu_pl_sof   : std_logic;
   signal cpu_pl_eof   : std_logic;
   signal cpu_pl_data  : std_logic_vector(7 downto 0);
   signal cpu_pl_ovf   : std_logic;
   signal cpu_pl_err   : std_logic;
   signal cpu_pl_drop  : std_logic;

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------

   inst_clk_rst : entity work.clk_rst
   generic map (
      G_RESET_SIZE => G_RESET_SIZE,
      G_SIMULATION => G_SIMULATION
   )
   port map (
      sys_clk100_i => clk100_i,
      sys_rstn_i   => sys_rstn_i,
      sys_step_i   => btn_i(0),
      sys_mode_i   => sw_i(0),
      vga_clk_o    => vga_clk,
      vga_rst_o    => vga_rst,
      cpu_clk_o    => cpu_clk,
      cpu_rst_o    => cpu_rst,
      eth_clk_o    => eth_clk,
      eth_rst_o    => eth_rst
   );


   ------------------------------
   -- Read SMI from PHY
   ------------------------------

   inst_read_smi : entity work.read_smi
   port map (
      clk_i       => eth_clk,
      rst_i       => eth_rst,
      ready_i     => eth_smi_ready,
      addr_o      => eth_smi_addr,
      rden_o      => eth_smi_rden,
      data_i      => eth_smi_data_out,
      registers_o => eth_smi_registers 
   );


   -----------------------------------
   -- Instantiate VGA -> ETH converter
   -----------------------------------

   inst_convert : entity work.convert
      port map (
         vga_clk_i    => vga_clk,
         vga_rst_i    => vga_rst,
         vga_col_i    => vga_col,
         vga_hs_i     => vga_hs,
         vga_vs_i     => vga_vs,
         vga_hcount_i => vga_hcount,
         vga_vcount_i => vga_vcount,

         eth_clk_i    => eth_clk,
         eth_rst_i    => eth_rst,
         eth_data_o   => eth_tx_data,
         eth_sof_o    => eth_tx_sof,
         eth_eof_o    => eth_tx_eof,
         eth_empty_o  => eth_tx_empty,
         eth_rden_i   => eth_tx_rden,

         fifo_error_o => fifo_error
      );


   ------------------------------
   -- Ethernet PHY
   ------------------------------

   inst_ethernet : entity work.ethernet
   port map (
      eth_clk_i      => eth_clk,
      eth_rst_i      => eth_rst,
      -- SMI interface
      smi_ready_o    => eth_smi_ready,
      smi_phy_i      => eth_smi_phy,
      smi_addr_i     => eth_smi_addr,
      smi_rden_i     => eth_smi_rden,
      smi_data_o     => eth_smi_data_out,
      smi_wren_i     => eth_smi_wren,
      smi_data_i     => eth_smi_data_in,
      --
      tx_data_i      => eth_tx_data,
      tx_sof_i       => eth_tx_sof,
      tx_eof_i       => eth_tx_eof,
      tx_empty_i     => eth_tx_empty,
      tx_rden_o      => eth_tx_rden,
      --
      rx_data_o      => eth_rx_data,
      rx_sof_o       => eth_rx_sof,
      rx_eof_o       => eth_rx_eof,
      rx_en_o        => eth_rx_en,
      rx_err_o       => eth_rx_err,
      rx_crc_valid_o => eth_rx_crc_valid,
      --
      eth_txd_o      => eth_txd_o,
      eth_txen_o     => eth_txen_o,
      eth_rxd_i      => eth_rxd_i,
      eth_rxerr_i    => eth_rxerr_i,
      eth_crsdv_i    => eth_crsdv_i,
      eth_intn_i     => eth_intn_i,
      eth_mdio_io    => eth_mdio_io,
      eth_mdc_o      => eth_mdc_o,
      eth_rstn_o     => eth_rstn_o,
      eth_refclk_o   => eth_refclk_o
   );

   proc_dat : process (eth_clk)
   begin
      if rising_edge(eth_clk) then
         if eth_rx_en = '1' and dat(dat'left downto dat'left-7) = 0 then
            dat <= dat(dat'left-8 downto 0) & eth_rx_data;
         end if;
         if eth_rx_en = '1' and eth_rx_sof = '1' then
            dat <= (others => '0');
            dat(7 downto 0) <= eth_rx_data;
         end if;
      end if;
   end process proc_dat;

   eth_debug(32*16-1 downto 8*16) <= (others => '0');
   eth_debug( 8*16-1 downto 0*16) <= dat;

   -------------------
   -- Ethernet receive
   -------------------
   
   inst_receive : entity work.receive
   port map (
      eth_clk_i       => eth_clk,
      eth_rst_i       => eth_rst,
      eth_ena_i       => eth_rx_en,
      eth_sof_i       => eth_rx_sof,
      eth_eof_i       => eth_rx_eof,
      eth_err_i       => eth_rx_err,
      eth_data_i      => eth_rx_data,
      eth_crc_valid_i => eth_rx_crc_valid,
      pl_clk_i        => cpu_clk,  
      pl_rst_i        => cpu_rst, 
      pl_ena_o        => cpu_pl_ena,
      pl_sof_o        => cpu_pl_sof,
      pl_eof_o        => cpu_pl_eof,
      pl_data_o       => cpu_pl_data
   ) ;


   ------------------------------
   -- Hack Computer!
   ------------------------------

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR  => true,              -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   => 11,                -- Number of bits in ROM address
      G_RAM_SIZE   => 11,                -- Number of bits in RAM address
      G_ROM_FILE   => "rom.txt",         -- Contains the machine code
      G_FONT_FILE  => "ProggyClean.txt"  -- Contains the character font
   )
   port map (
      vga_clk_i   => vga_clk,
      cpu_clk_i   => cpu_clk,
      cpu_rst_i   => cpu_rst,
      --
      ps2_clk_i   => ps2_clk_i,
      ps2_data_i  => ps2_data_i,
      --
      eth_debug_i => eth_debug,
      led_o       => open,
      --
      vga_hs_o     => vga_hs,
      vga_vs_o     => vga_vs,
      vga_col_o    => vga_col,
      vga_hcount_o => vga_hcount,
      vga_vcount_o => vga_vcount
   );

 
   led_o(15 downto 1) <= (others => '0');
   led_o(0) <= fifo_error;

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= col8to12(vga_col);
   
end Structural;

