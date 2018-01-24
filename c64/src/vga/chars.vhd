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

      config_i : in  std_logic_vector(128*8-1 downto 0);
      status_i : in  std_logic_vector(127 downto 0);

      disp_addr_o : out std_logic_vector(9 downto 0);
      disp_data_i : in  std_logic_vector(7 downto 0);

      font_addr_o : out std_logic_vector(11 downto 0);
      font_data_i : in  std_logic_vector(7 downto 0);

      hcount_o : out std_logic_vector(10 downto 0);
      vcount_o : out std_logic_vector(10 downto 0);
      hsync_o  : out std_logic;
      vsync_o  : out std_logic;
      col_o    : out std_logic_vector(11 downto 0)
   );
end chars;

architecture Behavioral of chars is

   constant C_DEBUG_POSX : integer := 20;
   constant C_DEBUG_POSY : integer :=  5;

   -- Convert colour from 8-bit format to 12-bit format
   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      return arg(7 downto 5) & "0" & arg(4 downto 2) & "0" & arg(1 downto 0) & "00";
   end function col8to12;

   -- This employs a five stage pipeline in order to improve timing.
   type t_stage is record
      hsync     : std_logic;                       -- valid in all stages
      vsync     : std_logic;                       -- valid in all stages
      hcount    : std_logic_vector(10 downto 0);   -- valid in all stages
      vcount    : std_logic_vector(10 downto 0);   -- valid in all stages
      blank     : std_logic;                       -- valid in all stages
      status    : std_logic_vector(127 downto 0);  -- Valid in stage 1
      char_x    : std_logic_vector(5 downto 0);    -- valid in stage 2 (0 - 39)
      char_y    : std_logic_vector(4 downto 0);    -- valid in stage 2 (0 - 17)
      pix_x     : std_logic_vector(2 downto 0);    -- valid in stage 2 (0 - 7)
      pix_y     : std_logic_vector(3 downto 0);    -- valid in stage 2 (0 - 12)
      char_addr : std_logic_vector(9 downto 0);
      nibble    : std_logic_vector(3 downto 0);
      font_addr : std_logic_vector(11 downto 0);
      pix       : std_logic;
      col       : std_logic_vector(11 downto 0);   -- valid in stage 5
   end record t_stage;

   constant STAGE_DEFAULT : t_stage := (
      hsync  => '0',
      vsync  => '0',
      hcount => (others => '0'),
      vcount => (others => '0'),
      blank  => '1',
      status => (others => '0'),
      char_x => (others => '0'),
      char_y => (others => '0'),
      pix_x  => (others => '0'),
      pix_y  => (others => '0'),
      char_addr => (others => '0'),
      nibble    => (others => '0'),
      font_addr => (others => '0'),
      pix    => '0',
      col    => (others => '0')
   );

   signal stage0 : t_stage := STAGE_DEFAULT;
   signal stage1 : t_stage := STAGE_DEFAULT;
   signal stage2 : t_stage := STAGE_DEFAULT;
   signal stage3 : t_stage := STAGE_DEFAULT;
   signal stage4 : t_stage := STAGE_DEFAULT;
   signal stage5 : t_stage := STAGE_DEFAULT;
   signal stage6 : t_stage := STAGE_DEFAULT;
   signal stage7 : t_stage := STAGE_DEFAULT;
   signal stage8 : t_stage := STAGE_DEFAULT;

   signal stage2_divmod13  : std_logic_vector(8 downto 0);
   signal stage4_char_val  : std_logic_vector(7 downto 0);
   signal stage6_row       : std_logic_vector(7 downto 0);
     
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
            stage1.blank  <= '1';
            stage1.status <= status_i;
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


   -- Propagate remaining signals.
   p_stage2 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage2 <= stage1;

         stage2.char_x <= stage1.hcount(9 downto 4);  -- (0 - 39)
         stage2.pix_x  <= stage1.hcount(3 downto 1);  -- (0 - 7)
      end if;
   end process p_stage2;


   ----------------------------------------------------
   -- Stage 3 : Calculate address into character memory
   ----------------------------------------------------

   p_stage3 : process (clk_i) is
      variable char_y_v : std_logic_vector(4 downto 0);
      variable pix_y_v  : std_logic_vector(3 downto 0);
   begin
      if rising_edge(clk_i) then
         stage3 <= stage2;

         char_y_v := stage2_divmod13(8 downto 4);   -- (quotient,  0 - 17)
         pix_y_v  := stage2_divmod13(3 downto 0);   -- (remainder, 0 - 12)

         stage3.char_y <= char_y_v;
         stage3.pix_y  <= pix_y_v;

         stage3.char_addr <= conv_std_logic_vector(
                             conv_integer(char_y_v)*40 + conv_integer(stage2.char_x),
                             10);
      end if;
   end process p_stage3;


   ----------------------------------------------------------
   -- Stage 4 : Read the character symbol from display memory
   --           Calculate nibble
   ----------------------------------------------------------

   disp_addr_o     <= stage3.char_addr;
   stage4_char_val <= disp_data_i;

   -- Propagate remaining signals.
   p_stage4 : process (clk_i) is
      variable char_x_v     : integer range 0 to 63;
      variable char_y_v     : integer range 0 to 63;
      variable nibble_idx_v : integer range 0 to 31;
   begin
      if rising_edge(clk_i) then
         stage4 <= stage3;
         if stage3.char_y >= C_DEBUG_POSY and stage3.char_y < C_DEBUG_POSY+8 and
            stage3.char_x >= C_DEBUG_POSX and stage3.char_x < C_DEBUG_POSX+4 then
            char_x_v     := conv_integer(stage3.char_x - C_DEBUG_POSX);
            char_y_v     := conv_integer(stage3.char_y - C_DEBUG_POSY);
            nibble_idx_v := char_y_v*4 + 3-char_x_v;
            stage4.nibble <= stage3.status(nibble_idx_v*4 + 3 downto nibble_idx_v*4);
         end if;
      end if;
   end process p_stage4;


   ------------------------------------------------------
   -- Stage 5 : Calculate address into character font ROM
   ------------------------------------------------------

   p_stage5 : process (clk_i) is
      variable char_val_v : std_logic_vector(7 downto 0);
   begin
      if rising_edge(clk_i) then
         stage5 <= stage4;
         stage5.font_addr <= stage4_char_val & stage4.pix_y;

         if stage4.char_y >= C_DEBUG_POSY and stage4.char_y < C_DEBUG_POSY+8 and
            stage4.char_x >= C_DEBUG_POSX and stage4.char_x < C_DEBUG_POSX+4 then
            char_val_v := stage4.nibble + X"30";
            if stage4.nibble > 9 then
               char_val_v := stage4.nibble + X"41" - X"0A";
            end if;
            stage5.font_addr <= char_val_v & stage4.pix_y;
         end if;
      end if;
   end process p_stage5;


   ----------------------------------------------------
   -- Stage 6 : Read the character bitmap from the ROM.
   ----------------------------------------------------

   font_addr_o <= stage5.font_addr;
   stage6_row  <= font_data_i;

   -- Propagate remaining signals.
   p_stage6 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage6 <= stage5;
      end if;
   end process p_stage6;


   ----------------------------------------
   -- Stage 7 : Determine the current pixel
   ----------------------------------------

   p_stage7 : process (clk_i) is
      variable pix : std_logic;
   begin
      if rising_edge(clk_i) then
         stage7 <= stage6;

         stage7.pix <= stage6_row(7-conv_integer(stage6.pix_x));
      end if;
   end process p_stage7;


   -----------------------------------------------------
   -- Stage 8 : Determine the color at the current pixel.
   -----------------------------------------------------

   -- Propagate remaining signals.
   p_stage8 : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         stage8 <= stage7;

         if stage7.pix = '1' then
            stage8.col <= col8to12(config_i(80*8 + 7 downto 80*8));
         else
            stage8.col <= col8to12(config_i(88*8 + 7 downto 88*8));
         end if;

         if stage7.blank = '1' then
            stage8.col <= X"000";
         end if;
      end if;
   end process p_stage8;


   -- Drive output signals
   hcount_o <= stage8.hcount;
   vcount_o <= stage8.vcount;
   hsync_o  <= stage8.hsync;
   vsync_o  <= stage8.vsync;
   col_o    <= stage8.col;

end Behavioral;

