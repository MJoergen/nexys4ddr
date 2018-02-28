library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level wrapper for the NEXYS4DDR board.
-- This is needed, because this design is meant to
-- work on both the BASYS2 and the NEXYS4DDR boards.
-- This file therefore contains all the stuff
-- peculiar to the NEXYS4DDR platform.

entity nexys4ddr is

   generic (
      G_SIMULATION : boolean := false
   );
   port (
      -- Clock
      clk100_i   : in  std_logic;   -- This pin is connected to an external 100 MHz crystal.

      -- Reset
      sys_rstn_i : in  std_logic;   -- Asserted low

      -- Input switches and push buttons
      sw_i       : in  std_logic_vector(15 downto 0);
      btn_i      : in  std_logic_vector(4 downto 0);

      -- Keyboard / mouse
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Output LEDs
      led_o      : out std_logic_vector(15 downto 0);

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
      eth_refclk_o : out   std_logic;        -- Connected to XTAL1/CLKIN. Must be driven to 50 MHz.
                                             -- All RMII signals are syunchronous to this clock.

      -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0)
   );
end nexys4ddr;

architecture Structural of nexys4ddr is

   -- Clocks and Reset
   signal vga_clk   : std_logic;
   signal cpu_clk   : std_logic;
   signal eth_clk   : std_logic;
   signal cpu_rst   : std_logic := '1';
 
   -- VGA color output
   signal vga_col   : std_logic_vector(7 downto 0);
 
   -- LED output
   signal led : std_logic_vector(7 downto 0);

   -- Convert colour from 8-bit format to 12-bit format
   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      return arg(7 downto 5) & "0" & arg(4 downto 2) & "0" & arg(1 downto 0) & "00";
   end function col8to12;

   signal mac_tx_data  : std_logic_vector(7 downto 0) := X"AE";
   signal mac_tx_sof   : std_logic := '1';
   signal mac_tx_eof   : std_logic := '1';
   signal mac_tx_empty : std_logic := '0';
   signal mac_tx_rden  : std_logic := '0';

   signal mac_smi_ready    : std_logic;
   signal mac_smi_phy      : std_logic_vector(4 downto 0) := "00001"; -- Constant.
   signal mac_smi_addr     : std_logic_vector(4 downto 0);
   signal mac_smi_rden     : std_logic := '0';
   signal mac_smi_data_out : std_logic_vector(15 downto 0);
   signal mac_smi_wren     : std_logic := '0';
   signal mac_smi_data_in  : std_logic_vector(15 downto 0);

begin

   proc_smi : process (eth_clk)
   begin
      if rising_edge(eth_clk) then
         if mac_smi_ready = '1' then
            mac_smi_wren     <= '1';
            mac_smi_data_in  <= X"ABCD";
            mac_smi_addr     <= "01010";
         end if;
      end if;
   end process proc_smi;


   gen_clocks : if G_SIMULATION = false generate
      -- Generate clocks
      inst_clk_wiz_0 : entity work.clk_wiz_0
      port map
      (
         clk_in1  => clk100_i,
         eth_clk => eth_clk,
         vga_clk => vga_clk,
         cpu_clk => cpu_clk
      );
   end generate gen_clocks;

   gen_no_clocks : if G_SIMULATION = true generate
      vga_clk <= clk100_i;
      cpu_clk <= clk100_i;
      eth_clk <= clk100_i;
   end generate gen_no_clocks;
 
 
   -- Generate synchronous CPU reset
   p_cpu_rst : process (cpu_clk)
   begin
      if rising_edge(cpu_clk) then
         cpu_rst <= not sys_rstn_i;     -- Synchronize and invert polarity.
      end if;
   end process p_cpu_rst;
 

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR  => true,              -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   => 11,                -- Number of bits in ROM address
      G_RAM_SIZE   => 11,                -- Number of bits in RAM address
      G_ROM_FILE   => "rom.txt",         -- Contains the machine code
      G_FONT_FILE  => "ProggyClean.txt"  -- Contains the character font
   )
   port map (
      vga_clk_i  => vga_clk,
      cpu_clk_i  => cpu_clk,
      cpu_rst_i  => cpu_rst,
      --
      mode_i     => sw_i(0),
      step_i     => btn_i(0),
      --
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      --
      led_o      => led,
      --
      vga_hs_o   => vga_hs_o,
      vga_vs_o   => vga_vs_o,
      vga_col_o  => vga_col
   );


   proc_gen_data : process (eth_clk)
      type t_mem is array (0 to 59) of std_logic_vector(7 downto 0);
      variable mem_v : t_mem := 
      -- MAC header
      (X"FF", X"FF", x"FF", X"FF", X"FF", X"FF",
       X"F4", X"6D", x"04", X"11", X"22", X"33",
       X"08", X"06",
       -- ARP data
       X"00", X"01", X"08", X"00", X"06", X"04", X"00", X"01",
       X"F4", X"6D", x"04", X"D7", X"F3", X"CA", X"C0", X"A8",
       X"01", X"2B", X"00", X"00", X"00", X"00", X"00", X"00",
       X"C0", X"A8", X"01", X"01",
       -- Padding
       X"00", X"01", X"02", X"03", X"04", X"05", X"06", X"07",
       X"08", X"09", X"0A", X"0B", X"0C", X"0D", X"0E", X"0F",
       X"10", X"11"
    );

      variable cnt_v : integer range 0 to 59 := 0;
   begin
      if rising_edge(eth_clk) then
         mac_tx_data  <= mem_v(cnt_v);
         mac_tx_empty <= '0';
         mac_tx_sof   <= '0';
         mac_tx_eof   <= '0';

         if cnt_v = 0 then
            mac_tx_sof <= '1';
         end if;
         if cnt_v = 59 then
            mac_tx_eof <= '1';
         end if;

         if mac_tx_rden = '1' then
            if cnt_v = 59 then
               cnt_v := 0;
            else
               cnt_v := cnt_v + 1;
            end if;
            mac_tx_data <= mem_v(cnt_v);
         end if;
      end if;
   end process proc_gen_data;


   inst_ethernet : entity work.ethernet
   port map (
      clk50_i      => eth_clk,
      -- SMI interface
      smi_ready_o  => mac_smi_ready,
      smi_phy_i    => mac_smi_phy,
      smi_addr_i   => mac_smi_addr,
      smi_rden_i   => mac_smi_rden,
      smi_data_o   => mac_smi_data_out,
      smi_wren_i   => mac_smi_wren,
      smi_data_i   => mac_smi_data_in,
      --
      tx_data_i    => mac_tx_data,
      tx_sof_i     => mac_tx_sof,
      tx_eof_i     => mac_tx_eof,
      tx_empty_i   => mac_tx_empty,
      tx_rden_o    => mac_tx_rden,
      --
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i,
      eth_mdio_io  => eth_mdio_io,
      eth_mdc_o    => eth_mdc_o,
      eth_rstn_o   => eth_rstn_o,
      eth_refclk_o => eth_refclk_o 
   );

 
   led_o(15 downto 8) <= (others => '0');
   led_o( 7 downto 0) <= led;

   vga_col_o <= col8to12(vga_col);
   
end Structural;

