----------------------------------------------------------------------------------
-- Description:  This generates the horizontal and vertical synchronization signals
--               for a VGA display with 1280 * 1024 @ 60 Hz refresh rate.
--               User must supply a 108 MHz clock on the input.
--               This is because 1688 * 1066 * 60 Hz = 107,96 MHz.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

use work.vga_bitmap_pkg.ALL;

entity vga_disp is
   port (
      vga_clk_i   : in  std_logic;   -- This must be 108 MHz

      vga_hsync_i : in  std_logic;
      vga_vsync_i : in  std_logic;
      hcount_i    : in  std_logic_vector(10 downto 0);
      vcount_i    : in  std_logic_vector(10 downto 0);
      blank_i     : in  std_logic;
      val_i       : in  std_logic_vector(1023 downto 0);

      vga_hsync_o : out std_logic;
      vga_vsync_o : out std_logic;
      vga_red_o   : out std_logic_vector(3 downto 0);
      vga_green_o : out std_logic_vector(3 downto 0);
      vga_blue_o  : out std_logic_vector(3 downto 0)
   );
end vga_disp;

architecture Behavioral of vga_disp is

   -- Screen pixel position to place the text.
   constant OFFSET_X    : integer := 600;
   constant OFFSET_Y    : integer := 400;

   -- This employs a six stage pipeline in order to improve timing.
   type t_stage is record
      hsync     : std_logic;                     -- valid in all stages
      vsync     : std_logic;                     -- valid in all stages
      hcount    : std_logic_vector(10 downto 0); -- valid in all stages
      vcount    : std_logic_vector(10 downto 0); -- valid in all stages
      blank     : std_logic;                     -- valid in all stages
      val       : std_logic_vector(31 downto 0); -- valid in stage 2
      hex       : std_logic_vector(3 downto 0);  -- valid in stage 3
      pix       : std_logic;                     -- valid in stage 4
      vga_color : std_logic_vector(11 downto 0); -- valid in stage 5
   end record t_stage;

   constant STAGE_DEFAULT : t_stage := (
      hsync     => '0',
      vsync     => '0',
      hcount    => (others => '0'),
      vcount    => (others => '0'),
      blank     => '1',
      val       => (others => '0'),
      hex       => (others => '0'),
      pix       => '0',
      vga_color => (others => '0'));

   signal stage0 : t_stage := STAGE_DEFAULT;
   signal stage1 : t_stage := STAGE_DEFAULT;
   signal stage2 : t_stage := STAGE_DEFAULT;
   signal stage3 : t_stage := STAGE_DEFAULT;
   signal stage4 : t_stage := STAGE_DEFAULT;
   signal stage5 : t_stage := STAGE_DEFAULT;

begin

   stage0.hsync  <= vga_hsync_i;
   stage0.vsync  <= vga_vsync_i;
   stage0.hcount <= hcount_i;
   stage0.vcount <= vcount_i;
   stage0.blank  <= blank_i;
   stage0.val    <= val_i(31 downto 0);

   -- Stage 1 : Make sure "val" is only sampled when off screen.
   p_stage1 : process (vga_clk_i) is
   begin
      if rising_edge(vga_clk_i) then
         stage1.hsync  <= stage0.hsync;
         stage1.vsync  <= stage0.vsync;
         stage1.hcount <= stage0.hcount;
         stage1.vcount <= stage0.vcount;
         stage1.blank  <= stage0.blank;

         if stage0.blank = '1' then
            stage1.val <= stage0.val; -- Only sample this value when off screen.
         end if;
      end if;
   end process p_stage1;

   -- Stage 2 : Synchronize the val
   p_stage2 : process (vga_clk_i) is
   begin
      if rising_edge(vga_clk_i) then
         stage2 <= stage1;
      end if;
   end process p_stage2;


   -- Stage 3 : Calculate the hex digit to be shown at the current position.
   p_stage3 : process (vga_clk_i) 
      variable offset : std_logic_vector(7 downto 0);
      variable nib    : integer range 0 to 7;

      -- Divide by 22 (= 2*CHAR_WIDTH)
      type offset_to_nib_t is array (0 to 255) of integer;
      constant offset_to_nib : offset_to_nib_t :=
      (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
       1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
       2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
       3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 
       4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 
       5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 
       6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
       0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

   begin
      if rising_edge(vga_clk_i) then
         stage3 <= stage2;

         offset := stage2.hcount(7 downto 0) - OFFSET_X;

         -- This is the particular hex digit to display.
         nib := offset_to_nib(conv_integer(offset));

         -- Each hex digit consumes 4 bits.
         stage3.hex <= stage2.val((7-nib)*4+3 downto (7-nib)*4);
      end if;
   end process p_stage3;


   -- Stage 4 : Calculate the pixel to be shown at the current position.
   p_stage4 : process (vga_clk_i)
      variable x_offset : std_logic_vector(7 downto 0);
      variable y_offset : std_logic_vector(3 downto 0);

      variable xdiff  : integer range 0 to CHAR_WIDTH-1;
      variable ydiff  : integer range 0 to CHAR_HEIGHT-1;
      variable bitmap : vga_bitmap_t;

      -- Modulus by 22 (= 2*CHAR_WIDTH)
      type offset_to_pix_t is array (0 to 255) of integer;
      constant offset_to_pix : offset_to_pix_t :=
      (0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10,
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10,
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10,
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10,
       0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6);

   begin
      if rising_edge(vga_clk_i) then
         stage4 <= stage3;

         x_offset := stage3.hcount(7 downto 0) - OFFSET_X;
         y_offset := stage3.vcount(4 downto 1) - OFFSET_Y/2;

         -- These are the pixel offsets in the hex digit bitmaps.
         xdiff := offset_to_pix(conv_integer(x_offset));
         ydiff := conv_integer(y_offset);

         -- Each hex digit consumes 4 bits.
         bitmap := vga_letters(conv_integer(stage3.hex));

         stage4.pix <= bitmap(ydiff*CHAR_WIDTH + xdiff);
      end if;
   end process p_stage4;


   -- Stage 5 : Generate the color at the current position
   p_stage5 : process (vga_clk_i) is
      variable hcount : integer;
      variable vcount : integer;
   begin
      if rising_edge(vga_clk_i) then 
         stage5 <= stage4;

         hcount := conv_integer(stage4.hcount);
         vcount := conv_integer(stage4.vcount);

         stage5.vga_color <= vga_black; -- Outside visible area, the color must be black.

         if stage4.blank = '0' then
            stage5.vga_color <= vga_gray; -- Default background color on screen.

            -- There are 8 characters horizontally. Each character is 2*CHAR_WIDTH
            -- pixels wide.
            if (hcount >= OFFSET_X) and (hcount < OFFSET_X + 2*CHAR_WIDTH*8)
            and (vcount >= OFFSET_Y) and (vcount < OFFSET_Y + 2*CHAR_HEIGHT) then
               if stage4.pix = '1' then
                  stage5.vga_color <= vga_dark;
               end if;
            end if;

         end if;
      end if;

   end process p_stage5;

   vga_red_o   <= stage5.vga_color(11 downto 8);
   vga_green_o <= stage5.vga_color( 7 downto 4);
   vga_blue_o  <= stage5.vga_color( 3 downto 0);
   vga_hsync_o <= stage5.hsync;
   vga_vsync_o <= stage5.vsync;

end Behavioral;

