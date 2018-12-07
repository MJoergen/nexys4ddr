library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can execute all instructions.
--
-- Additionally, the CPU registers are shown on the VGA display.
-- The registers shown are:
-- * WREN (1 byte) and DATA OUT (1 byte)
-- * ADDR (2 bytes)
-- * HI (1 byte) and LO (1 byte)
-- * DATA IN (1 byte) and 'A' register (1 byte)
-- * PC (2 bytes)
-- * Instruction Register (1 byte) and Instruction Cycle Count (1 bytes)
--
-- The speed of the execution is controlled by the slide switches.

entity comp is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);
      led_o     : out std_logic_vector(7 downto 0);
      rstn_i    : in  std_logic;

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture structural of comp is

   constant C_OVERLAY_BITS  : integer := 176;
   constant C_ROM_INIT_FILE : string := "../rom.txt";
   constant C_OPCODES_FILE  : string := "opcodes.txt";
   constant C_FONT_FILE     : string := "font8x8.txt";

   -- MAIN Clock domain
   signal main_clk     : std_logic;
   signal main_rst     : std_logic;
   signal main_rst_shr : std_logic_vector(7 downto 0) := X"FF";
   signal main_wait    : std_logic;
   signal main_overlay : std_logic_vector(C_OVERLAY_BITS-1 downto 0);

   -- VGA Clock doamin
   signal vga_clk      : std_logic;
   signal vga_overlay  : std_logic_vector(C_OVERLAY_BITS-1 downto 0);

begin
   
   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   clk_inst : entity work.clk_wiz_0_clk_wiz
   port map (
      clk_in1  => clk_i,
      eth_clk  => open, -- Not needed yet.
      vga_clk  => vga_clk,
      main_clk => main_clk
   ); -- clk_inst


   --------------------------------------------------
   -- Generate Reset
   --------------------------------------------------

   main_rst_proc : process (main_clk)
   begin
      if rising_edge(main_clk) then
         -- Hold reset asserted for a number of clock cycles.
         main_rst     <= main_rst_shr(0);
         main_rst_shr <= "0" & main_rst_shr(main_rst_shr'left downto 1);

         if rstn_i = '0' then
            main_rst_shr <= (others => '1');
         end if;
      end if;
   end process main_rst_proc;

   
   --------------------------------------------------
   -- Instantiate Waiter
   --------------------------------------------------

   waiter_inst : entity work.waiter
   port map (
      clk_i  => main_clk,
      inc_i  => sw_i,
      wait_o => main_wait
   ); -- waiter_inst


   --------------------------------------------------
   -- Instantiate MAIN module
   --------------------------------------------------

   main_inst : entity work.main
   generic map (
      G_ROM_INIT_FILE => C_ROM_INIT_FILE,
      G_OVERLAY_BITS  => C_OVERLAY_BITS
   )
   port map (
      clk_i     => main_clk,
      rst_i     => main_rst,
      wait_i    => main_wait,
      led_o     => led_o,
      overlay_o => main_overlay
   ); -- main_inst


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   vga_inst : entity work.vga
   generic map (
      G_OVERLAY_BITS => C_OVERLAY_BITS,
      G_OPCODES_FILE => C_OPCODES_FILE,
      G_FONT_FILE    => C_FONT_FILE
   )
   port map (
      clk_i     => vga_clk,
      digits_i  => vga_overlay,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o
   ); -- vga_inst


   --------------------------------------------------
   -- Instantiate clock crossing from MAIN to VGA
   --------------------------------------------------

   cdc_overlay_inst : entity work.cdc
   generic map (
      G_WIDTH => C_OVERLAY_BITS
   )
   port map (
      src_clk_i  => main_clk,
      src_data_i => main_overlay,
      dst_clk_i  => vga_clk,
      dst_data_o => vga_overlay
   ); -- cdc_overlay_inst

end architecture structural;

