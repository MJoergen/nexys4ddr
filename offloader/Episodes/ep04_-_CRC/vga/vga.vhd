library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module drives the VGA interface of the design.
-- The screen resolution generated is 640x480 @ 60 Hz, with 256 colours.
-- This module expects an input clock rate of approximately 25.175 MHz. It will
-- work with a clock rate of 25.0 MHz.
--
-- This module takes an input of 32 bytes (256 bits), and displays this in the
-- first row of the screen as 64 hexadecimal characters.

entity vga is
   port (
      clk_i     : in  std_logic;    -- Expects 25.175 MHz. Works with 25.0 MHz.

      hex_i     : in  std_logic_vector(255 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)
   );
end vga;

architecture structural of vga is

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Number of 8x8 characters on screen
   constant H_CHARS : integer := H_PIXELS/8;    -- 80
   constant V_CHARS : integer := V_PIXELS/8;    -- 60

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

   -- Define colours
   constant COL_BLACK : std_logic_vector(11 downto 0) := B"0000_0000_0000";
   constant COL_DARK  : std_logic_vector(11 downto 0) := B"0101_0101_0101";
   constant COL_GREY  : std_logic_vector(11 downto 0) := B"1010_1010_1010";
   constant COL_WHITE : std_logic_vector(11 downto 0) := B"1111_1111_1111";
   constant COL_RED   : std_logic_vector(11 downto 0) := B"1111_0000_0000";
   constant COL_GREEN : std_logic_vector(11 downto 0) := B"0000_1111_0000";
   constant COL_BLUE  : std_logic_vector(11 downto 0) := B"0000_0000_1111";

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0);
   signal pix_y : std_logic_vector(9 downto 0);

   -- This record contains all the registers used in the pipeline.
   type t_vga is record
      -- Valid after stage 1
      pix_x  : std_logic_vector(9 downto 0);
      pix_y  : std_logic_vector(9 downto 0);
      hs     : std_logic;
      vs     : std_logic;
      addr   : std_logic_vector(10 downto 0);

      -- Valid after stage 2
      bitmap : std_logic_vector(7 downto 0);

      -- Valid after stage 3
      col    : std_logic_vector(11 downto 0);
   end record t_vga;

   signal stage1 : t_vga;
   signal stage2 : t_vga;
   signal stage3 : t_vga;

begin

   ---------------------------------------------------
   -- Generate horizontal and vertical pixel counters
   ---------------------------------------------------

   i_pix : entity work.pix
   port map (
      clk_i   => clk_i,
      pix_x_o => pix_x,
      pix_y_o => pix_y
   ); -- i_pix


   ---------------------------------------------
   -- Stage 1
   -- This stage calculates hs, vs, and addr
   ---------------------------------------------

   p_stage1 : process (clk_i)
      variable v_char_row : std_logic_vector(6 downto 0);   -- 0 to 79, i.e. 80 columns
      variable v_char_col : std_logic_vector(6 downto 0);   -- 0 to 59, i.e. 60 rows
      variable v_char_num : std_logic_vector(13 downto 0);  -- 0 to 4799, i.e. one of the 80x60 characters on screen.
      variable v_hex_idx  : integer range 0 to 63;          -- Selects which of the 64 hexadecimal characters to display.
      variable v_hex      : std_logic_vector(3 downto 0);   -- Value of current 4-bit nibble.
      variable v_char     : std_logic_vector(7 downto 0);   -- ASCII code of current character.
      variable v_addr     : std_logic_vector(10 downto 0);  -- Address into font ROM.
   begin
      if rising_edge(clk_i) then
         stage1.pix_x <= pix_x;
         stage1.pix_y <= pix_y;

         if pix_x >= HS_START and pix_x < HS_START+HS_TIME then
            stage1.hs <= '1';
         else
            stage1.hs <= '0';
         end if;

         if pix_y >= VS_START and pix_y < VS_START+VS_TIME then
            stage1.vs <= '1';
         else
            stage1.vs <= '0';
         end if;

         -- Determine character row and column.
         v_char_row := pix_y(9 downto 3);
         v_char_col := pix_x(9 downto 3);

         -- Each character on the screen is numbered 0 to 4799.
         v_char_num := v_char_row * H_CHARS + v_char_col;

         -- Determine which hexadecimal character to display now.
         v_hex_idx  := 63 - to_integer(v_char_num(5 downto 0));

         -- Read hexadecimal value from input.
         v_hex      := hex_i(v_hex_idx*4+3 downto v_hex_idx*4);

         -- Convert hexadecimal value to ASCII.
         v_char     := X"20"; -- Default to a space character.
         if v_char_num < 64 then
            v_char  := v_hex + X"30" when v_hex < X"A" else v_hex - X"A" + X"41";
         end if;

         -- Calculate address in font ROM.
         v_addr     := v_char & pix_y(2 downto 0);

         stage1.addr <= v_addr;

      end if;
   end process p_stage1;


   ---------------------------------------------
   -- Stage 2
   -- Read bitmap of current character
   ---------------------------------------------

   i_rom : entity work.rom
   generic map (
      G_ROM_FILE  => "font8x8.txt",
      G_ADDR_SIZE => 11,
      G_DATA_SIZE => 8
   )
   port map (
      clk_i  => clk_i,
      addr_i => stage1.addr,
      data_o => stage2.bitmap
   ); -- i_rom


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
   -- This stage calculates col.
   ---------------------------------------------

   p_stage3 : process (clk_i)
      variable v_offset_x : std_logic_vector(2 downto 0);
   begin
      if rising_edge(clk_i) then

         -- Copy signals from previous stage
         stage3 <= stage2;

         -- Calculate position within character bitmap
         v_offset_x := stage2.pix_x(2 downto 0);

         -- Set the colour
         if stage2.bitmap(to_integer(v_offset_x)) = '1' then
            stage3.col <= COL_WHITE;
         else
            stage3.col <= COL_DARK;
         end if;

         -- Make sure colour is black outside visible screen
         if stage2.pix_x >= H_PIXELS or stage2.pix_y >= V_PIXELS then
            stage3.col <= (others => '0');  -- Black
         end if;

      end if;
   end process p_stage3;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= stage3.hs;
   vga_vs_o  <= stage3.vs;
   vga_col_o <= stage3.col;

end architecture structural;

