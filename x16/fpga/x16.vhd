library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the X16. The ports on this entity are mapped
-- directly to pins on the FPGA.
--
-- This version supports outputting the current CPU state to the VGA screen.


entity x16 is
   port (
      clk_i        : in    std_logic;                       -- 100 MHz

      rstn_i       : in    std_logic;                       -- CPU reset, active low

      sw_i         : in    std_logic_vector(7 downto 0);    -- Used for debugging.
      led_o        : out   std_logic_vector(7 downto 0);    -- Used for debugging.

      ps2_clk_i    : in    std_logic;                       -- Keyboard
      ps2_data_i   : in    std_logic;

      vga_hs_o     : out   std_logic;                       -- VGA
      vga_vs_o     : out   std_logic;
      vga_col_o    : out   std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end x16;

architecture structural of x16 is

   constant C_ROM_INIT_FILE : string := "../rom.txt";       -- ROM contents.
   constant C_FONT_FILE     : string := "font8x8.txt";      -- Initial fonts for VERA.

   signal vga_clk           : std_logic;   -- 25 MHz
   signal cpu_clk           : std_logic;   --  8 MHz

   signal cpu_rst           : std_logic;
   signal cpu_irq           : std_logic;
   signal cpu_addr          : std_logic_vector(15 downto 0);
   signal cpu_data_read     : std_logic_vector( 7 downto 0);
   signal cpu_wren          : std_logic;
   signal cpu_rden          : std_logic;
   signal cpu_data_write    : std_logic_vector( 7 downto 0);

begin

   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   i_clk : entity work.clk_wiz_0_clk_wiz
      port map (
         clk_in1 => clk_i,    -- 100 MHz
         vga_clk => vga_clk,  --  25 MHz
         cpu_clk => cpu_clk   --   8 MHz
      ); -- i_clk


   --------------------------------------------------
   -- Instantiate VERA module
   --------------------------------------------------

   i_vera : entity work.vera
      generic map (
         G_FONT_FILE => C_FONT_FILE
      )
      port map (
         clk_i     => vga_clk,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vera


   --------------------------------------------------
   -- Instantiate CPU 65C02 module
   --------------------------------------------------

   i_cpu_65c02 : entity work.cpu_65c02
      port map (
         clk_i     => cpu_clk,
         rst_i     => cpu_rst,
         nmi_i     => '0',
         irq_i     => '0', -- TBD
         addr_o    => cpu_addr,
         data_i    => cpu_data_read,
         wren_o    => cpu_wren,
         rden_o    => cpu_rden,
         data_o    => cpu_data_write
      ); -- i_cpu_65c02


end architecture structural;

