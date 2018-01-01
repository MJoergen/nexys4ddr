library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity hack is

   generic (
      G_CHAR_FILE : string := "charset1.bin.txt"
   );
   port (
      -- Clock
      clk_i     : in  std_logic;  -- 100 MHz

      -- Reset
      rstn_i    : in  std_logic;  -- Asserted low

      -- Input switches and push buttons
      sw_i      : in  std_logic_vector (15 downto 0);
      btn_i     : in  std_logic_vector ( 4 downto 0);

     -- Output to VGA monitor
      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)
  );

end hack;

architecture Structural of hack is

   signal clk_vga : std_logic;
   signal rst_vga : std_logic := '1';  -- Asserted high.
   
begin

   -- Generate VGA clock
   inst_clk_wiz_vga : entity work.clk_wiz_vga
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => clk_vga  -- 25 MHz
   );

   -- Generate reset synchronous to VGA clock.
   p_rst_vga : process (clk_vga)
   begin
      if rising_edge(clk_vga) then
         rst_vga <= not rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_rst_vga;


   -- Instantiate VGA module
   inst_vga_module : entity work.vga_module
   generic map (
                  G_CHAR_FILE => G_CHAR_FILE 
               )
   port map (
      clk_i => clk_vga,
      rst_i => rst_vga,
      hs_o  => vga_hs_o,
      vs_o  => vga_vs_o,
      col_o => vga_col_o
   );

end Structural;

