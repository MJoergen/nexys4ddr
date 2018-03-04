library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

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
   signal sys_rstn_debounce : std_logic := '0';
   signal cpu_clk_stepped : std_logic;
   signal eth_rst   : std_logic := '1';
 
   -- VGA color output
   signal vga_col   : std_logic_vector(7 downto 0);
 
   -- LED output
   signal led : std_logic;

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
   signal mac_smi_addr     : std_logic_vector(4 downto 0) := "00000";
   signal mac_smi_rden     : std_logic := '0';
   signal mac_smi_data_out : std_logic_vector(15 downto 0);
   signal mac_smi_wren     : std_logic := '0';
   signal mac_smi_data_in  : std_logic_vector(15 downto 0);

   signal mac_smi_registers : std_logic_vector(32*16-1 downto 0) := (others => '0');

   signal clk_step     : std_logic;
   signal clk_mode     : std_logic;
   signal clk_mode_inv : std_logic;

   signal eth_rstn   : std_logic;
   signal eth_refclk : std_logic;

   signal pl_ena      : std_logic := '0';
   signal pl_sof      : std_logic;
   signal pl_eof      : std_logic;
   signal pl_data     : std_logic_vector(7 downto 0);

begin

   ------------------------------
   -- Instantiate Debounce
   ------------------------------

   inst_reset_debounce : entity work.debounce
   port map (
      clk_i => clk100_i,
      in_i  => sys_rstn_i,
      out_o => sys_rstn_debounce
   );

   inst_step_debounce : entity work.debounce
   port map (
      clk_i => clk100_i,
      in_i  => btn_i(0),
      out_o => clk_step
   );

   inst_mode_debounce : entity work.debounce
   port map (
      clk_i => clk100_i,
      in_i  => sw_i(0),
      out_o => clk_mode
   );


   ------------------------------
   -- Generate clocks
   ------------------------------

   gen_clocks : if G_SIMULATION = false generate
      -- Generate clocks
      inst_clk_wiz_0 : entity work.clk_wiz_0
      port map
      (
         clk_in1 => clk100_i,
         eth_clk => eth_clk,
         vga_clk => vga_clk,
         cpu_clk => cpu_clk
      );

      clk_mode_inv <= not clk_mode;

      -- Note: For some reason, synthesis fails if I0 and I1 are swapped.
      inst_bufgmux : BUFGCTRL
      port map (
         IGNORE0 => '0',
         IGNORE1 => '0',
         S0      => '1',
         S1      => '1',
         I1      => cpu_clk,
         I0      => clk_step,
         CE0     => clk_mode,
         CE1     => clk_mode_inv,
         O       => cpu_clk_stepped
      );
   end generate gen_clocks;

   gen_no_clocks : if G_SIMULATION = true generate
      vga_clk <= clk100_i;
      cpu_clk <= clk100_i;
      eth_clk <= clk100_i;
      cpu_clk_stepped <= cpu_clk when clk_mode = '0' else clk_step;
   end generate gen_no_clocks;
 
 
   ------------------------------
   -- Generate reset
   ------------------------------

   p_cpu_rst : process (cpu_clk)
   begin
      if rising_edge(cpu_clk) then
         cpu_rst <= not sys_rstn_debounce;     -- Synchronize and invert polarity.
      end if;
   end process p_cpu_rst;
 
   p_eth_rst : process (eth_clk)
   begin
      if rising_edge(eth_clk) then
         eth_rst <= not sys_rstn_debounce;     -- Synchronize and invert polarity.
      end if;
   end process p_eth_rst;
 

   ------------------------------
   -- Read SMI from PHY
   ------------------------------

   proc_smi : process (eth_clk)
      variable state_v : std_logic_vector(1 downto 0);
   begin
      if rising_edge(eth_clk) then
         state_v := mac_smi_ready & mac_smi_rden;
         case state_v is
            when "10" => -- Start new read
               -- Store result.
               mac_smi_registers(conv_integer(mac_smi_addr)*16 + 15 downto conv_integer(mac_smi_addr)*16) <= mac_smi_data_out;
               -- Start next read.
               mac_smi_addr <= mac_smi_addr + 1;
               mac_smi_rden <= '1';

            when "11" => -- Wait for acknowledge
               null;
            when "01" => -- Read acknowledged
               mac_smi_rden <= '0';
            when "00" => -- Wait for result
               null;
            when others =>
               null;
         end case;
      end if;
   end process proc_smi;


   ------------------------------
   -- Generate test data
   ------------------------------

   proc_gen_data : process (eth_clk)
      type t_mem is array (0 to 59) of std_logic_vector(7 downto 0);
      variable mem_v : t_mem := 
      -- MAC header
      (X"FF", X"FF", x"FF", X"FF", X"FF", X"FF",
       X"F4", X"6D", x"04", X"11", X"22", X"33",
       X"08", X"06",
       -- ARP data
       X"00", X"01", X"08", X"00", X"06", X"04", X"00", X"01",
       X"F4", X"6D", x"04", X"11", X"22", X"33", X"C0", X"A8",
       X"01", X"2D", X"00", X"00", X"00", X"00", X"00", X"00",
       X"C0", X"A8", X"01", X"01",
       -- Padding
       X"00", X"01", X"02", X"03", X"04", X"05", X"06", X"07",
       X"08", X"09", X"0A", X"0B", X"0C", X"0D", X"0E", X"0F",
       X"10", X"11"

       -- The CRC for the above packet shall be
       -- X"3F", X"45", X"2B", X"4F"
    );

      variable cnt_v : integer range 0 to 59 := 0;
   begin
      if rising_edge(vga_clk) then
         pl_data  <= mem_v(cnt_v);
         pl_sof   <= '0';
         pl_eof   <= '0';
         pl_ena   <= '1';

         if pl_eof = '1' then
            pl_ena <= '0';
            pl_sof <= '0';
            pl_eof <= '0';
         end if;

         if cnt_v = 0 then
            pl_sof <= '1';
            led <= not led;
         end if;

         if cnt_v < 59 then
            cnt_v := cnt_v + 1;
         else
            pl_eof <= '1';
         end if;

         if eth_rstn = '0' then
            cnt_v := 0;
            pl_ena <= '0';
            pl_sof <= '0';
            pl_eof <= '0';
         end if;
      end if;
   end process proc_gen_data;


   inst_encap : entity work.encap
   port map (
      pl_clk_i       => vga_clk,
      pl_rst_i       => '0',
      pl_ena_i       => pl_ena,
      pl_sof_i       => pl_sof,
      pl_eof_i       => pl_eof,
      pl_data_i      => pl_data,
      ctrl_mac_dst_i => X"FFFFFFFFFFFF",
      ctrl_mac_src_i => X"F46D04112233",
      ctrl_ip_dst_i  => X"C0A8012D",
      ctrl_ip_src_i  => X"C0A8012E",
      ctrl_udp_dst_i => X"1234",
      ctrl_udp_src_i => X"2345",
      mac_clk_i      => eth_clk,
      mac_rst_i      => eth_rst,
      mac_data_o     => mac_tx_data,
      mac_sof_o      => mac_tx_sof,
      mac_eof_o      => mac_tx_eof,
      mac_empty_o    => mac_tx_empty,
      mac_rden_i     => mac_tx_rden
   );


   ------------------------------
   -- Ethernet PHY
   ------------------------------

   inst_ethernet : entity work.ethernet
   port map (
      clk50_i      => eth_clk,
      rst_i        => eth_rst,
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
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => eth_refclk 
   );


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
      cpu_clk_i   => cpu_clk_stepped,
      cpu_rst_i   => cpu_rst,
      --
      ps2_clk_i   => ps2_clk_i,
      ps2_data_i  => ps2_data_i,
      --
      eth_debug_i => mac_smi_registers,
      led_o       => open,
      --
      vga_hs_o    => vga_hs_o,
      vga_vs_o    => vga_vs_o,
      vga_col_o   => vga_col
   );

 
   led_o(15 downto 3) <= (others => '0');
   led_o(0) <= led;
   led_o(1) <= eth_rstn;
   led_o(2) <= eth_refclk;

   eth_rstn_o   <= eth_rstn;
   eth_refclk_o <= eth_refclk;

   vga_col_o <= col8to12(vga_col);
   
end Structural;

