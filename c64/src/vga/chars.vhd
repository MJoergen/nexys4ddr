---------------------------------------------------------------------------------
-- This generates a 320 x 234 pixel screen, consisting of 8 x 13 pixel characters.
-- This corresponds to 40 x 18 characters.
-- The character memory consists of 40x18 = 720 bytes. They are placed in a 10->8 RAM.
--
-- In order to calculate the character and pixel row, the y coordinate must
-- be divided by 13. This is handled by a 8->9 RAM, where the address is the 
-- y coordinate (pixel 0 to 233) and the data is 5 bits of quotient (character row 0
-- to 17) and 4 bits of remainder (pixel row 0 to 12).
-- The address into the character memory is then calculated as 40*row + col.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity chars is
   port (
      clk_i    : in  std_logic;

      hcount_i : in  std_logic_vector(10 downto 0);
      vcount_i : in  std_logic_vector(10 downto 0);
      hsync_i  : in  std_logic;
      vsync_i  : in  std_logic;
      blank_i  : in  std_logic;

      disp_addr_o : out std_logic_vector(9 downto 0);
      disp_data_i : in  std_logic_vector(7 downto 0);

      font_addr_o  : out std_logic_vector(11 downto 0);
      font_data_i  : in  std_logic_vector(7 downto 0);

      hcount_o : out std_logic_vector(10 downto 0);
      vcount_o : out std_logic_vector(10 downto 0);
      hsync_o  : out std_logic;
      vsync_o  : out std_logic;
      col_o    : out std_logic_vector(11 downto 0)
   );
end chars;

architecture Behavioral of chars is

   -- This employs a five stage pipeline in order to improve timing.
   type t_stage is record
      hsync     : std_logic;                       -- valid in all stages
      vsync     : std_logic;                       -- valid in all stages
      hcount    : std_logic_vector(10 downto 0);   -- valid in all stages
      vcount    : std_logic_vector(10 downto 0);   -- valid in all stages
      blank     : std_logic;                       -- valid in all stages
      char_x    : std_logic_vector(5 downto 0);    -- valid in stage 2 (0 - 39)
      char_y    : std_logic_vector(4 downto 0);    -- valid in stage 2 (0 - 17)
      pix_x     : std_logic_vector(2 downto 0);    -- valid in stage 2 (0 - 7)
      pix_y     : std_logic_vector(3 downto 0);    -- valid in stage 2 (0 - 12)
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
      col    => (others => '0')
   );

   signal stage0 : t_stage := STAGE_DEFAULT;
   signal stage1 : t_stage := STAGE_DEFAULT;
   signal stage2 : t_stage := STAGE_DEFAULT;
   signal stage3 : t_stage := STAGE_DEFAULT;
   signal stage4 : t_stage := STAGE_DEFAULT;
   signal stage5 : t_stage := STAGE_DEFAULT;

   signal stage2_divmod13  : std_logic_vector(8 downto 0);
   signal stage2_char_y    : std_logic_vector(4 downto 0);
   signal stage2_pix_y     : std_logic_vector(3 downto 0);
   signal stage2_char_addr : std_logic_vector(9 downto 0);

   signal stage3_char_val  : std_logic_vector(7 downto 0);
   signal stage3_addr      : std_logic_vector(11 downto 0);

   signal stage4_row       : std_logic_vector(7 downto 0);
     
begin

   stage0.hsync   <= hsync_i;
   stage0.vsync   <= vsync_i;
   stage0.hcount  <= hcount_i;
   stage0.vcount  <= vcount_i;
   stage0.blank   <= blank_i;


   ------------------------------------------------------------------------
   -- Stage 1 : Make sure signals from other clock domains are only sampled
   -- when off screen.
   -- Additionally, shift the screen 3 pixels down.
   ------------------------------------------------------------------------

   p_stage1 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage1.hsync  <= stage0.hsync;
         stage1.vsync  <= stage0.vsync;
         stage1.hcount <= stage0.hcount;
         stage1.vcount <= stage0.vcount - 6;
         stage1.blank  <= stage0.blank;
         if (stage0.vcount < 6 or stage0.vcount >= 13*18*2 + 6) then
            stage1.blank <= '1';
         end if;
      end if;
   end process p_stage1;


   ----------------------------------------------------------
   -- Stage 2 : Calculate the character and pixel coordinates
   ----------------------------------------------------------

   i_divmod13_rom : entity work.rom_file
   generic map (
                  G_RD_CLK_RIS => true,
                  G_ADDR_SIZE  => 8,
                  G_DATA_SIZE  => 9,
                  G_ROM_FILE   => "divmod13.txt"
               )
   port map (
               clk_i  => clk_i,
               addr_i => stage1.vcount(8 downto 1),
               rden_i => '1',
               data_o => stage2_divmod13
            );

   stage2_char_y <= stage2_divmod13(8 downto 4);   -- (quotient,  0 - 17)
   stage2_pix_y  <= stage2_divmod13(3 downto 0);   -- (remainder, 0 - 12)

   -- Calculate address into character memory
   stage2_char_addr <= conv_std_logic_vector(
                       conv_integer(stage2_char_y)*40 + conv_integer(stage2.char_x),
                       10);

   -- Propagate remaining signals.
   p_stage2 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage2 <= stage1;

         stage2.char_x <= stage1.hcount(9 downto 4);  -- (0 - 39)
         stage2.pix_x  <= stage1.hcount(3 downto 1);  -- (0 - 7)
      end if;
   end process p_stage2;

   ----------------------------------------------------------
   -- Stage 3 : Read the character symbol from display memory
   ----------------------------------------------------------

   disp_addr_o     <= stage2_char_addr;
   stage3_char_val <= disp_data_i;

   -- Calculate address into character bitmap ROM.
   stage3_addr <= stage3_char_val & stage3.pix_y;

   -- Propagate remaining signals.
   p_stage3 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage3 <= stage2;

         stage3.char_y <= stage2_char_y;
         stage3.pix_y  <= stage2_pix_y;
      end if;
   end process p_stage3;


   ----------------------------------------------------
   -- Stage 4 : Read the character bitmap from the ROM.
   ----------------------------------------------------

   font_addr_o <= stage3_addr;
   stage4_row  <= font_data_i;

   -- Propagate remaining signals.
   p_stage4 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage4 <= stage3;
      end if;
   end process p_stage4;


   -----------------------------------------------------
   -- Stage 5 : Determine the color at the current pixel.
   -----------------------------------------------------

   -- Propagate remaining signals.
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


   -- Drive output signals
   hcount_o <= stage5.hcount;
   vcount_o <= stage5.vcount;
   hsync_o  <= stage5.hsync;
   vsync_o  <= stage5.vsync;
   col_o    <= stage5.col;

end Behavioral;

