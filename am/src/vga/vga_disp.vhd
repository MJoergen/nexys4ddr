----------------------------------------------------------------------------------
-- Description:  This generates a display for a 640 x 480 bit screen.
--               Everything is scaled by two, so the effective resolution is
--               only 320 x 240 pixels. This corresponds to 40x30 characters,
--               where each character is 8x8 pixels.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vga_disp is
   generic (
      G_CHAR_FILE : string
   );
   port (
      clk_i    : in  std_logic;

      hcount_i : in  std_logic_vector(10 downto 0);
      vcount_i : in  std_logic_vector(10 downto 0);
      hsync_i  : in  std_logic;
      vsync_i  : in  std_logic;
      blank_i  : in  std_logic;

      hcount_o : out std_logic_vector(10 downto 0);
      vcount_o : out std_logic_vector(10 downto 0);
      hsync_o  : out std_logic;
      vsync_o  : out std_logic;
      col_o    : out std_logic_vector(11 downto 0)
   );
end vga_disp;

architecture Behavioral of vga_disp is

   -- This employs a five stage pipeline in order to improve timing.
   type t_stage is record
      hsync     : std_logic;                       -- valid in all stages
      vsync     : std_logic;                       -- valid in all stages
      hcount    : std_logic_vector(10 downto 0);   -- valid in all stages
      vcount    : std_logic_vector(10 downto 0);   -- valid in all stages
      blank     : std_logic;                       -- valid in all stages
      char_x    : std_logic_vector(5 downto 0);    -- valid in stage 2
      char_y    : std_logic_vector(4 downto 0);    -- valid in stage 2
      pix_x     : std_logic_vector(2 downto 0);    -- valid in stage 2
      pix_y     : std_logic_vector(2 downto 0);    -- valid in stage 2
      char      : std_logic_vector(7 downto 0);    -- valid in stage 3
      row       : std_logic_vector(7 downto 0);    -- valid in stage 4
      col       : std_logic_vector(11 downto 0);   -- valid in stage 5
   end record t_stage;

   constant STAGE_DEFAULT : t_stage := (
      hsync  => '0',
      vsync  => '0',
      hcount => (others => '0'),
      vcount => (others => '0'),
      blank  => '1',
      char_x => (others => '0'),
      char_y => (others => '0'),
      pix_x  => (others => '0'),
      pix_y  => (others => '0'),
      char   => (others => '0'),
      row    => (others => '0'),
      col    => (others => '0')
   );

   signal stage0 : t_stage := STAGE_DEFAULT;
   signal stage1 : t_stage := STAGE_DEFAULT;
   signal stage2 : t_stage := STAGE_DEFAULT;
   signal stage3 : t_stage := STAGE_DEFAULT;
   signal stage4 : t_stage := STAGE_DEFAULT;
   signal stage5 : t_stage := STAGE_DEFAULT;

   signal stage4_row : std_logic_vector(7 downto 0);
     
begin

   stage0.hsync   <= hsync_i;
   stage0.vsync   <= vsync_i;
   stage0.hcount  <= hcount_i;
   stage0.vcount  <= vcount_i;
   stage0.blank   <= blank_i;

   -- Stage 1 : Make sure signals from other clock domains are only sampled
   -- when off screen.
   p_stage1 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage1.hsync  <= stage0.hsync;
         stage1.vsync  <= stage0.vsync;
         stage1.hcount <= stage0.hcount;
         stage1.vcount <= stage0.vcount;
         stage1.blank  <= stage0.blank;
      end if;
   end process p_stage1;

   -- Stage 2 : Calculate character and pixel positions.
   p_stage2 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage2 <= stage1;
         stage2.char_x <= stage1.hcount(9 downto 4);
         stage2.char_y <= stage1.vcount(8 downto 4);
         stage2.pix_x  <= stage1.hcount(3 downto 1);
         stage2.pix_y  <= stage1.vcount(3 downto 1);
      end if;
   end process p_stage2;

   -- Stage 3 : Determine which character to display.
   p_stage3 : process (clk_i) is
      variable char_x : integer;
      variable char_y : integer;
      variable char : integer range 0 to 255;
   begin
      if rising_edge(clk_i) then
         stage3 <= stage2;
         char_x := conv_integer(stage2.char_x);
         char_y := conv_integer(stage2.char_y);
         char := ((char_y*40) + char_x) mod 256;
         stage3.char <= std_logic_vector(to_unsigned(char, 8));
      end if;
   end process p_stage3;

   -- Stage 4 : Read the character bitmap from the ROM.
   i_char_rom : entity work.vga_char_rom
   generic map (
                  G_CHAR_FILE => G_CHAR_FILE 
               )
   port map (
               clk_i  => clk_i,
               addr_i => stage3.char,
               row_i  => stage3.pix_y,
               data_o => stage4_row
            );

   -- Stage 4 :
   p_stage4 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage4 <= stage3;
      end if;
   end process p_stage4;

   -- Stage 5 : Determine the color at the current pixel.
   p_stage5 : process (clk_i) is
      variable pix : std_logic;
   begin
      if rising_edge(clk_i) then
         stage5 <= stage4;
         pix := stage4_row(7-conv_integer(stage4.pix_x));
         if pix = '1' then
            stage5.col <= X"444";
         else
            stage5.col <= X"CCC";
         end if;

         if stage4.blank = '1' then
            stage5.col <= X"000";
         end if;
      end if;
   end process p_stage5;

   hcount_o <= stage5.hcount;
   vcount_o <= stage5.vcount;
   hsync_o  <= stage5.hsync;
   vsync_o  <= stage5.vsync;
   col_o    <= stage5.col;

end Behavioral;

