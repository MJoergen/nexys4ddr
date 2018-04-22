-----------------------------------------------------------------------------
-- Description:  This generates sprites as an overlay.
--               Only 4 sprites are supported to keep resource requirements at
--               a minimum.
--
-- Configuration information is provided in the config_i signal, and includes
-- * 0x00-0x07 X-position  (2 bytes pr MOB)
-- * 0x08-0x0B Y-position
-- * 0x0C-0x0F Color
-- * 0x10-0x13 Enable (bit 0) & Magnify (bits 2-1)
-- * 0x18 Foreground text colour
-- * 0x19 Background text colour
-- * 0x1A Horizontal pixel shift
-- * 0x1B Y-line interrupt
-- * 0x1C IRQ status
-- * 0x1D IRQ mask
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity sprites is
   port (
      clk_i         : in  std_logic;

      hcount_i      : in  std_logic_vector(10 downto 0);
      vcount_i      : in  std_logic_vector(10 downto 0);
      hs_i          : in  std_logic;
      vs_i          : in  std_logic;
      blank_i       : in  std_logic;
      col_i         : in  std_logic_vector( 7 downto 0);

      config_i      : in  std_logic_vector(32*8-1 downto 0);

      bitmap_addr_o : out std_logic_vector( 5 downto 0);
      bitmap_data_i : in  std_logic_vector(15 downto 0);

      hcount_o      : out std_logic_vector(10 downto 0);
      vcount_o      : out std_logic_vector(10 downto 0);
      hs_o          : out std_logic;
      vs_o          : out std_logic;
      blank_o       : out std_logic;
      col_o         : out std_logic_vector( 7 downto 0);
      collision_o   : out std_logic_vector( 3 downto 0)
   );
end sprites;

architecture Behavioral of sprites is

   constant C_XPOS : integer := 0;
   constant C_YPOS : integer := 8;
   constant C_COL  : integer := 12;
   constant C_ENA  : integer := 16;

   -- This is the same value as defined in vga/sync.vhd
   constant H_MAX   : natural := 800;            -- H total period (pixels)

   signal fsm_addr  : std_logic_vector(4*4-1 downto 0) := (others => '0');
   signal fsm_rden  : std_logic_vector(3 downto 0) := (others => '0');

   -- Signals connected to the sprite bitmap BRAM
   signal bitmap_addr   : std_logic_vector( 5 downto 0) := (others => '0');
   signal bitmap_rden   : std_logic := '0';

   -- State machine to read sprite bitmaps from BRAM
   signal bitmap_rden_d : std_logic := '0';
   signal bitmap_addr_d : std_logic_vector(5 downto 0) := (others => '0');
   signal bitmap_rows   : std_logic_vector(16*4-1 downto 0) := (others => '0');

   ----------------------------------------------------------------------

   -- Pipeline
   type t_stage is record
      hcount          : std_logic_vector(10 downto 0);     -- Valid in stage 0
      vcount          : std_logic_vector(10 downto 0);     -- Valid in stage 0
      hs              : std_logic;                         -- Valid in stage 0
      vs              : std_logic;                         -- Valid in stage 0
      blank           : std_logic;                         -- Valid in stage 0
      col             : std_logic_vector( 7 downto 0);     -- Valid in stage 0
      row_index       : std_logic_vector(4*4-1 downto 0);  -- Valid in stage 1 (0 - 15) for each sprite
      row_index_valid : std_logic_vector(3 downto 0);      -- Valid in stage 1
      col_index       : std_logic_vector(4*4-1 downto 0);  -- Valid in stage 1 (0 - 15) for each sprite
      col_index_valid : std_logic_vector(3 downto 0);      -- Valid in stage 1
      pix             : std_logic_vector(3 downto 0);      -- Valid in stage 2
      collision       : std_logic_vector(3 downto 0);      -- Valid in stage 2
   end record t_stage;

   constant STAGE_DEFAULT : t_stage := (
      hcount          => (others => '0'),
      vcount          => (others => '0'),
      hs              => '0',
      vs              => '0',
      blank           => '0',
      col             => (others => '0'),
      row_index       => (others => '0'),
      row_index_valid => (others => '0'),
      col_index       => (others => '0'),
      col_index_valid => (others => '0'),
      pix             => (others => '0'),
      collision       => (others => '0')
   );

   signal stage0 : t_stage := STAGE_DEFAULT;
   signal stage1 : t_stage := STAGE_DEFAULT;
   signal stage2 : t_stage := STAGE_DEFAULT;
   signal stage3 : t_stage := STAGE_DEFAULT;

   type t_posx    is array(natural range <>) of std_logic_vector(8 downto 0);
   type t_posy    is array(natural range <>) of std_logic_vector(7 downto 0);
   type t_color   is array(natural range <>) of std_logic_vector(7 downto 0);
   type t_enable  is array(natural range <>) of std_logic;
   type t_magnify is array(natural range <>) of std_logic_vector(1 downto 0);

   signal posx_s    : t_posx(3 downto 0);
   signal posy_s    : t_posy(3 downto 0);
   signal color_s   : t_color(3 downto 0);
   signal enable_s  : t_enable(3 downto 0);
   signal magnify_s : t_magnify(3 downto 0);

   function shift_left(arg : std_logic_vector; shift : integer) return std_logic_vector is
      variable res_v : std_logic_vector(arg'length-1 downto 0);
   begin
      res_v := (others => '0');
      res_v(arg'length-1 downto shift) := arg(arg'length-1-shift downto 0);
      return res_v;
   end function shift_left;

   function shift_right(arg : std_logic_vector; shift : integer) return std_logic_vector is
      variable res_v : std_logic_vector(arg'length-1 downto 0);
   begin
      res_v := (others => '0');
      res_v(arg'length-1-shift downto 0) := arg(arg'length-1 downto shift);
      return res_v;
   end function shift_right;

begin

   ------------------------------------------------------------------------
   -- Decode configuration data
   ------------------------------------------------------------------------

   gen_config : for i in 0 to 3 generate
      posx_s(i)    <= config_i((C_XPOS+2*i)*8 + 8 downto (C_XPOS+2*i)*8);
      posy_s(i)    <= config_i((C_YPOS+i)*8 + 7 downto (C_YPOS+i)*8);
      color_s(i)   <= config_i((C_COL+i)*8 + 7 downto (C_COL+i)*8);
      enable_s(i)  <= config_i((C_ENA+i)*8);
      magnify_s(i) <= config_i((C_ENA+i)*8 + 2 downto (C_ENA+i)*8 + 1);
   end generate gen_config;


   ------------------------------------------------------------------------
   -- Control reading sprite bitmaps from the BRAM.
   -- Reading starts when hcount_i = -22 and takes one clock cycle pr sprite.
   -- With 4 sprites, the bitmap data is ready at start of the next line (-16).
   ------------------------------------------------------------------------

   p_fsm : process (clk_i)
      variable vcount1_v : std_logic_vector(10 downto 0);
      variable pix_y_v  : std_logic_vector( 9 downto 0);
   begin
      if rising_edge(clk_i) then

         -- Get ready to read bitmap data
         if hcount_i = H_MAX-22 then
            vcount1_v := vcount_i + 1;  -- Next line

            -- Loop over all sprites.
            for i in 0 to 3 loop

               -- Get pixel row in this sprite
               pix_y_v := shift_right(vcount1_v(10 downto 1) - ("00" & posy_s(i)),
                  conv_integer(magnify_s(i)));

               fsm_rden(i) <= '0';
               if pix_y_v <= 15 then
                  fsm_rden(i) <= enable_s(i);
               end if;
               fsm_addr(4*(i+1)-1 downto 4*i) <= pix_y_v(3 downto 0);
            end loop;
         end if;
      end if;
   end process p_fsm;


   p_read_bitmap : process (clk_i)
      variable pix_x_v      : std_logic_vector(10 downto 0);
      variable sprite_num_v : std_logic_vector(1 downto 0);
   begin
      if rising_edge(clk_i) then
         pix_x_v := hcount_i - (H_MAX-21);
         bitmap_rden <= '0';

         if pix_x_v < 4 then
            sprite_num_v := pix_x_v(1 downto 0); -- Read one sprite every pixel (clock)
            bitmap_addr <= sprite_num_v & fsm_addr(
                           conv_integer(sprite_num_v)*4 + 3 downto
                           conv_integer(sprite_num_v)*4 + 0);
            bitmap_rden <= fsm_rden(conv_integer(sprite_num_v));
         end if;
      end if;
   end process p_read_bitmap;


   --------------------
   -- Store bitmap data
   --------------------

   -- Store for use next clock cycle
   p_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         bitmap_rden_d <= bitmap_rden;
         bitmap_addr_d <= bitmap_addr;
      end if;
   end process p_delay;

   gen_bitmap_row : for i in 0 to 3 generate
      p_bitmap_row : process (clk_i)
      begin
         if rising_edge(clk_i) then
            if bitmap_rden_d = '1' and conv_integer(bitmap_addr_d(5 downto 4)) = i then
               bitmap_rows(i*16 + 15 downto i*16) <= bitmap_data_i;
            end if;
         end if;
      end process p_bitmap_row;
   end generate gen_bitmap_row;

   -- Drive output signal
   bitmap_addr_o <= bitmap_addr;
   

   ----------------------------
   -- Stage 0
   ----------------------------

   stage0.hcount <= hcount_i;
   stage0.vcount <= vcount_i;
   stage0.hs     <= hs_i;
   stage0.vs     <= vs_i;
   stage0.blank  <= blank_i;
   stage0.col    <= col_i;


   ----------------------------------------
   -- Stage 1 : Calculate horizontal
   ----------------------------------------

   p_stage1 : process (clk_i)
      variable pix_x_v : std_logic_vector(8 downto 0);
      variable pix_y_v : std_logic_vector(7 downto 0);
   begin
      if rising_edge(clk_i) then
         stage1 <= stage0;

         stage1.col_index_valid <= (others => '0');
         stage1.row_index_valid <= (others => '0');

         for i in 0 to 3 loop
            pix_x_v := shift_right(stage0.hcount(9 downto 1) - (posx_s(i)),
               conv_integer(magnify_s(i)));
            stage1.col_index(4*(i+1)-1 downto 4*i) <= pix_x_v(3 downto 0);
            if pix_x_v <= 15 then
               stage1.col_index_valid(i) <= enable_s(i);
            end if;

            pix_y_v := shift_right(stage0.vcount(8 downto 1) - (posy_s(i)),
               conv_integer(magnify_s(i)));
            stage1.row_index(4*(i+1)-1 downto 4*i) <= pix_y_v(3 downto 0);
            if pix_y_v <= 15 then
               stage1.row_index_valid(i) <= enable_s(i);
            end if;
         end loop;

      end if;
   end process p_stage1;


   ----------------------------------------
   -- Stage 2 : Calculate pixel
   ----------------------------------------

   p_stage2 : process (clk_i)
      variable col_index_v : integer range 0 to 15;
   begin
      if rising_edge(clk_i) then
         stage2 <= stage1;

         stage2.pix <= (others => '0');
         for i in 3 downto 0 loop
            if stage1.row_index_valid(i) = '1' and stage1.col_index_valid(i) = '1' then
               col_index_v := conv_integer(stage1.col_index(i*4 + 3 downto i*4));
               stage2.pix(i) <= bitmap_rows(i*16 + col_index_v);
            end if;
         end loop;

      end if;
   end process p_stage2;


   ----------------------------------------
   -- Stage 3 : Calculate color and collision
   ----------------------------------------

   p_stage3 : process (clk_i)
   begin
      if rising_edge(clk_i) then
         stage3 <= stage2;

         for i in 3 downto 0 loop
            if stage2.pix(i) = '1' then
               stage3.col <= color_s(i);
            end if;
         end loop;

         -- More than 1 bit set in stage2.pix indicates collision between two
         -- or more sprites.
         stage3.collision <= (others => '0');
         if (stage2.pix and (stage2.pix - 1)) /= 0 then
            stage3.collision <= stage2.pix;
         end if;

      end if;
   end process p_stage3;


   ----------------------------------------
   -- Drive output signals
   ----------------------------------------

   hcount_o    <= stage3.hcount;
   vcount_o    <= stage3.vcount;
   hs_o        <= stage3.hs;
   vs_o        <= stage3.vs;
   blank_o     <= stage3.blank;
   col_o       <= stage3.col;
   collision_o <= stage3.collision;

end Behavioral;

