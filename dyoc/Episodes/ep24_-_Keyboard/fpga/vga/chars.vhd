library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

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

      palette_i   : in  std_logic_vector(16*8-1 downto 0);

      pix_x_o     : out std_logic_vector(9 downto 0);
      pix_y_o     : out std_logic_vector(9 downto 0);
      vga_hs_o    : out std_logic;
      vga_vs_o    : out std_logic;
      vga_col_o   : out std_logic_vector(7 downto 0)
   );
end chars;

architecture structural of chars is

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
      bitmap  : std_logic_vector(63 downto 0);

      -- Valid after stage 3
      pix_col : std_logic_vector(7 downto 0);
   end record t_vga;

   signal stage0 : t_vga;
   signal stage1 : t_vga;
   signal stage2 : t_vga;
   signal stage3 : t_vga;

begin

   ---------------------------------------------
   -- Stage 0
   -- This stage copies pix_x and pix_y.
   ---------------------------------------------

   stage0.pix_x <= pix_x_i;
   stage0.pix_y <= pix_y_i;


   ---------------------------------------------
   -- Stage 1
   -- This stage calculates hs, vs, and addr
   ---------------------------------------------

   p_stage1 : process (clk_i)
      variable v_char_x : std_logic_vector(6 downto 0);
      variable v_char_y : std_logic_vector(6 downto 0);
   begin
      if rising_edge(clk_i) then
         -- Copy signals from previous stage
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

         -- Calculate lookup address in character and colour memories.
         v_char_x := stage0.pix_x(9 downto 3);
         v_char_y := stage0.pix_y(9 downto 3);

         stage1.addr <= to_std_logic_vector(to_integer(v_char_y) * H_CHARS + to_integer(v_char_x), 13);
      end if;
   end process p_stage1;


   ---------------------------------------------
   -- Stage 2
   -- Read character and colour from memory
   ---------------------------------------------

   char_addr_o  <= stage1.addr;
   col_addr_o   <= stage1.addr;
   stage2.char  <= char_data_i;
   stage2.color <= col_data_i;


   ---------------------------------------------
   -- Stage 2
   -- Read bitmap of character
   ---------------------------------------------

   i_font : entity work.font
   generic map (
      G_FONT_FILE => G_FONT_FILE
   )
   port map (
      char_i   => stage2.char,
      bitmap_o => stage2.bitmap
   );


   ---------------------------------------------
   -- Stage 2
   -- Copy remaining signals from previous stage
   ---------------------------------------------

   p_stage2 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage2.pix_x <= stage1.pix_x;
         stage2.pix_y <= stage1.pix_y;
         stage2.hs    <= stage1.hs;
         stage2.vs    <= stage1.vs;
         stage2.addr  <= stage1.addr;
      end if;
   end process p_stage2;


   ---------------------------------------------
   -- Stage 3
   -- This stage calculates pix_col.
   ---------------------------------------------

   p_stage3 : process (clk_i)
      variable v_offset_x : std_logic_vector(2 downto 0);
      variable v_offset_y : std_logic_vector(2 downto 0);
      variable v_offset_bitmap : integer range 0 to 63;
      variable v_colour   : integer range 0 to 15;
   begin
      if rising_edge(clk_i) then

         -- Copy signals from previous stage
         stage3 <= stage2;

         v_offset_x := stage2.pix_x(2 downto 0);
         v_offset_y := 7-stage2.pix_y(2 downto 0);

         v_offset_bitmap := to_integer(v_offset_y) * 8 + to_integer(v_offset_x);

         -- Set the colour
         if stage2.bitmap(v_offset_bitmap) = '1' then
            v_colour := to_integer(stage2.color(3 downto 0));
         else
            v_colour := to_integer(stage2.color(7 downto 4));
         end if;
         stage3.pix_col <= palette_i(v_colour*8+7 downto v_colour*8);

         -- Make sure colour is black outside visible screen
         if stage2.pix_x >= H_PIXELS or stage2.pix_y >= V_PIXELS then
            stage3.pix_col <= (others => '0');  -- Black
         end if;

      end if;
   end process p_stage3;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= stage3.hs;
   vga_vs_o  <= stage3.vs;
   vga_col_o <= stage3.pix_col;
   pix_x_o   <= stage3.pix_x;
   pix_y_o   <= stage3.pix_y;

end architecture structural;

