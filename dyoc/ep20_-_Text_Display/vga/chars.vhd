library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity chars is
   generic (
      G_FONT_FILE : string
   );
   port (
      clk_i       : in  std_logic;

      pix_x_i     : in  std_logic_vector(9 downto 0);
      pix_y_i     : in  std_logic_vector(9 downto 0);

      char_addr_o : out std_logic_vector(12 downto 0);
      char_data_i : in  std_logic_vector( 7 downto 0);
      col_addr_o  : out std_logic_vector(12 downto 0);
      col_data_i  : in  std_logic_vector( 7 downto 0);

      pix_x_o     : out std_logic_vector(9 downto 0);
      pix_y_o     : out std_logic_vector(9 downto 0);
      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_col_o   : out std_logic_vector(7 downto 0)
   );
end chars;

architecture Structural of chars is

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Number of 8x8 characters on screen
   constant H_CHARS : integer := H_PIXELS/8;
   constant V_CHARS : integer := V_PIXELS/8;

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

   -- This record contains all the registers used in the pipeline.
   type t_vga is record
      -- Valid after stage 0
      pix_x   : std_logic_vector(9 downto 0);
      pix_y   : std_logic_vector(9 downto 0);

      -- Valid after stage 1
      hs      : std_logic;
      vs      : std_logic;
      addr    : std_logic_vector(12 downto 0);

      -- Valid after stage 2
      char    : std_logic_vector(7 downto 0);
      color   : std_logic_vector(7 downto 0);

      -- Valid after stage 3
      bitmap  : std_logic_vector(63 downto 0);

      -- Valid after stage 4
      pix_col : std_logic_vector(7 downto 0);
   end record t_vga;

   signal stage0 : t_vga;
   signal stage1 : t_vga;
   signal stage2 : t_vga;
   signal stage3 : t_vga;
   signal stage4 : t_vga;

   signal stage2_char   : std_logic_vector( 7 downto 0);
   signal stage2_col    : std_logic_vector( 7 downto 0);
   signal stage2_bitmap : std_logic_vector(63 downto 0);

begin

   ----------
   -- Stage 0
   ----------

   stage0.pix_x <= pix_x_i;
   stage0.pix_y <= pix_y_i;


   ----------
   -- Stage 1
   ----------

   p_stage1 : process (clk_i)
      variable v_char_x : std_logic_vector(6 downto 0);
      variable v_char_y : std_logic_vector(6 downto 0);
   begin
      if rising_edge(clk_i) then
         stage1 <= stage0;

         if stage0.pix_x >= HS_START and stage0.pix_x < HS_START+HS_TIME then
            stage1.hs <= '0';
         else
            stage1.hs <= '1';
         end if;

         if stage0.pix_y >= VS_START and stage0.pix_y < VS_START+VS_TIME then
            stage1.vs <= '0';
         else
            stage1.vs <= '1';
         end if;

         v_char_x := stage0.pix_x(9 downto 3);
         v_char_y := stage0.pix_y(9 downto 3);

         stage1.addr <= std_logic_vector(to_unsigned(
                       conv_integer(v_char_y) * H_CHARS + conv_integer(v_char_x), 13));
      end if;
   end process p_stage1;


   ----------------------------------------
   -- Read character and colour from memory
   ----------------------------------------

   char_addr_o <= stage1.addr;
   col_addr_o  <= stage1.addr;
   stage2_char <= char_data_i;
   stage2_col  <= col_data_i;


   ----------
   -- Stage 2
   ----------

   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2 <= stage1;
      end if;
   end process p_stage2;


   ---------------------------
   -- Read bitmap of character
   ---------------------------

   i_font : entity work.font
   generic map (
      G_FONT_FILE => G_FONT_FILE
   )
   port map (
      char_i   => stage2_char,
      bitmap_o => stage2_bitmap
   );


   ----------
   -- Stage 3
   ----------

   p_stage3 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage3 <= stage2;
         stage3.char   <= stage2_char;
         stage3.color  <= stage2_col;
         stage3.bitmap <= stage2_bitmap;
      end if;
   end process p_stage3;



   ----------
   -- Stage 4
   ----------

   p_stage4 : process (clk_i)
      variable v_offset_x : std_logic_vector(2 downto 0);
      variable v_offset_y : std_logic_vector(2 downto 0);
      variable v_offset_bitmap : integer range 0 to 63;
   begin
      if rising_edge(clk_i) then

         stage4 <= stage3;

         v_offset_x := stage3.pix_x(2 downto 0);
         v_offset_y := stage3.pix_y(2 downto 0);

         v_offset_bitmap := conv_integer(v_offset_y) * 8 + conv_integer(v_offset_x);

         -- Set the text background colour
         stage4.pix_col <= (others => '0');  -- Black

         if stage3.bitmap(v_offset_bitmap) = '1' then
            stage4.pix_col <= stage3.color;
         end if;

         -- Make sure colour is black outside visible screen
         if stage3.pix_x >= H_PIXELS or stage3.pix_y >= V_PIXELS then
            stage4.pix_col <= (others => '0');  -- Black
         end if;

      end if;
   end process p_stage4;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= stage4.hs;
   vga_vs_o  <= stage4.vs;
   vga_col_o <= stage4.pix_col;
   pix_x_o   <= stage4.pix_x;
   pix_y_o   <= stage4.pix_y;

end architecture Structural;

