library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the X16. The ports on this entity are mapped
-- directly to pins on the FPGA.

entity x16 is
   port (
      clk_i      : in    std_logic;                       -- 100 MHz

      rstn_i     : in    std_logic;                       -- CPU reset, active low

      sw_i       : in    std_logic_vector(7 downto 0);    -- Used for debugging.
      led_o      : out   std_logic_vector(7 downto 0);    -- Used for debugging.

      ps2_clk_i  : in    std_logic;                       -- Keyboard
      ps2_data_i : in    std_logic;

      vga_hs_o   : out   std_logic;                       -- VGA
      vga_vs_o   : out   std_logic;
      vga_col_o  : out   std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end x16;

architecture structural of x16 is

   constant C_ROM_INIT_FILE : string := "../rom.txt";       -- ROM contents.

   signal vga_clk_s         : std_logic;   -- 25.2 MHz

   signal cpu_clk_s         : std_logic;   --  8.33 MHz
   signal cpu_addr_s        : std_logic_vector(15 downto 0);
   signal cpu_wr_en_s       : std_logic;
   signal cpu_wr_data_s     : std_logic_vector( 7 downto 0);
   signal cpu_rd_en_s       : std_logic;
   signal cpu_rd_data_s     : std_logic_vector( 7 downto 0);

begin

   --------------------------------------------------
   -- Instantiate Clock generation
   --------------------------------------------------

   i_clk : entity work.clk_wiz_0_clk_wiz
      port map (
         clk_in1 => clk_i,      -- 100 MHz
         vga_clk => vga_clk_s,  --  25.2 MHz
         cpu_clk => cpu_clk_s   --   8.33 MHz
      ); -- i_clk


   --------------------------------------------------
   -- Instantiate VERA module
   --------------------------------------------------

   i_vera : entity work.vera
      port map (
         cpu_clk_i     => cpu_clk_s,
         cpu_addr_i    => cpu_addr_s(2 downto 0),
         cpu_wr_en_i   => cpu_wr_en_s,
         cpu_wr_data_i => cpu_wr_data_s,
         cpu_rd_en_i   => cpu_rd_en_s,
         cpu_rd_data_o => cpu_rd_data_s,
         vga_clk_i     => vga_clk_s,
         vga_hs_o      => vga_hs_o,
         vga_vs_o      => vga_vs_o,
         vga_col_o     => vga_col_o
      ); -- i_vera


   --------------------------------------------------
   -- Instantiate dummy CPU module
   -- TBD: To be replaced by the 65C02 processor
   --------------------------------------------------

   i_cpu_dummy : entity work.cpu_dummy
      port map (
         clk_i     => cpu_clk_s,
         addr_o    => cpu_addr_s(2 downto 0),
         wr_en_o   => cpu_wr_en_s,
         wr_data_o => cpu_wr_data_s,
         rd_en_o   => cpu_rd_en_s,
         rd_data_i => cpu_rd_data_s
      ); -- i_cpu_dummy

end architecture structural;

