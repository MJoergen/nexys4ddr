library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module controls the view, i.e. the position of the top left corner of
-- the picture (startx, starty) and the size of a pixel (stepx, stepy), all in
-- 2.16 fixed point format. The view is changed by the buttons, once for each
-- pulse on upd_i:
--   btn_i(4)         : Zoom in, or zoom out if zoom_out_i is set. The size of
--                      a pixel changes by 1/64 of its value plus one LSB.
--   btn_i(3 downto 2): Pan left and right by one pixel.
--   btn_i(1 downto 0): Pan up and down by one pixel.
--
-- The view is always kept inside the range of the 2.16 format, i.e. -2 to 2
-- (not including 2), so that the values of cx and cy calculated by the
-- dispatcher and the column modules never wrap around. This means:
-- * The left (top) edge is never less than -2. Panning stops there.
-- * The right (bottom) edge, i.e. the value of the last column (row), is never
--   2 or more. Panning stops there.
-- * The size of a pixel is at least one LSB (2^-16). Zooming in stops there.
-- * Zooming keeps the top left corner fixed. When zooming out would move the
--   right (bottom) edge out of range, the view is moved left (up) instead, so
--   the edge stays at the end of the range. Zooming out stops when the view
--   can not get any larger.
--
-- Internally the positions are handled in offset binary, i.e. as the value
-- plus 2, which is in the range 0 to 4. This is the 2.16 value with the sign
-- bit inverted, interpreted as an unsigned number.

entity view is
   generic (
      G_NUM_COLS : integer;
      G_NUM_ROWS : integer;
      G_START_X  : real;     -- Initial view
      G_START_Y  : real;
      G_SIZE_X   : real;
      G_SIZE_Y   : real
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      upd_i      : in  std_logic;
      btn_i      : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      zoom_out_i : in  std_logic;
      startx_o   : out std_logic_vector(17 downto 0);
      starty_o   : out std_logic_vector(17 downto 0);
      stepx_o    : out std_logic_vector(17 downto 0);
      stepy_o    : out std_logic_vector(17 downto 0)
   );
end entity view;

architecture rtl of view is

   -- The largest position, i.e. 2-2^-16, in offset binary
   constant C_MAX_POS  : natural := 2**18-1;

   -- The smallest size of a pixel (one LSB)
   constant C_MIN_STEP : natural := 1;

   -- Inverts the sign bit, to convert between 2.16 and offset binary
   constant C_SIGN     : std_logic_vector(17 downto 0) := "10" & X"0000";

   -- Multiply by a constant using only shifts and additions. This makes sure
   -- that synthesis does not use a DSP for it, because they are all used by
   -- the iterators.
   function mult_const (v : natural; k : natural) return natural is
      variable res : natural := 0;
   begin
      for i in 0 to 10 loop
         if (k / 2**i) mod 2 = 1 then
            res := res + v * 2**i;
         end if;
      end loop;
      return res;
   end function mult_const;

   -- Initial values, in 2.16 format
   constant C_INIT_STARTX : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer((G_START_X+4.0)*real(2**16)), 18);
   constant C_INIT_STARTY : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer((G_START_Y+4.0)*real(2**16)), 18);
   constant C_INIT_STEPX  : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer(G_SIZE_X*real(2**16))/G_NUM_COLS, 18);
   constant C_INIT_STEPY  : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer(G_SIZE_Y*real(2**16))/G_NUM_ROWS, 18);

   signal startx : std_logic_vector(17 downto 0);
   signal starty : std_logic_vector(17 downto 0);
   signal stepx  : std_logic_vector(17 downto 0);
   signal stepy  : std_logic_vector(17 downto 0);

begin

   assert G_NUM_COLS <= 2**11 and G_NUM_ROWS <= 2**11
      report "mult_const only supports constants below 2^11"
      severity failure;

   p_view : process (clk_i)
      variable posx_v  : natural range 0 to 2**19-1;  -- Offset binary
      variable posy_v  : natural range 0 to 2**19-1;  -- Offset binary
      variable stepx_v : natural range 0 to 2**18-1;
      variable stepy_v : natural range 0 to 2**18-1;
      variable zoomx_v : integer range -1 to 2**19-1;
      variable zoomy_v : integer range -1 to 2**19-1;
      variable sizex_v : natural range 0 to 2**30-1;  -- From first to last column
      variable sizey_v : natural range 0 to 2**30-1;  -- From first to last row
   begin
      if rising_edge(clk_i) then
         if upd_i = '1' then
            posx_v  := to_integer(startx xor C_SIGN);
            posy_v  := to_integer(starty xor C_SIGN);
            stepx_v := to_integer(stepx);
            stepy_v := to_integer(stepy);

            -- Zoom. This is only done if the new view fits in the range.
            if btn_i(4) = '1' then
               if zoom_out_i = '1' then
                  zoomx_v := stepx_v + stepx_v/64 + 1;
                  zoomy_v := stepy_v + stepy_v/64 + 1;
               else
                  zoomx_v := stepx_v - stepx_v/64 - 1;
                  zoomy_v := stepy_v - stepy_v/64 - 1;
               end if;

               if zoomx_v >= C_MIN_STEP and zoomy_v >= C_MIN_STEP and
                  mult_const(zoomx_v, G_NUM_COLS-1) <= C_MAX_POS and
                  mult_const(zoomy_v, G_NUM_ROWS-1) <= C_MAX_POS
               then
                  stepx_v := zoomx_v;
                  stepy_v := zoomy_v;
               end if;
            end if;

            sizex_v := mult_const(stepx_v, G_NUM_COLS-1);
            sizey_v := mult_const(stepy_v, G_NUM_ROWS-1);

            -- Pan. The right button has priority over the left button, and the
            -- down button over the up button.
            if btn_i(2) = '1' then
               posx_v := posx_v + stepx_v;
            elsif btn_i(3) = '1' then
               if posx_v >= stepx_v then
                  posx_v := posx_v - stepx_v;
               else
                  posx_v := 0;
               end if;
            end if;

            if btn_i(0) = '1' then
               posy_v := posy_v + stepy_v;
            elsif btn_i(1) = '1' then
               if posy_v >= stepy_v then
                  posy_v := posy_v - stepy_v;
               else
                  posy_v := 0;
               end if;
            end if;

            -- Keep the right and bottom edges in range. This is needed after
            -- panning right or down, and after zooming out.
            if posx_v + sizex_v > C_MAX_POS then
               posx_v := C_MAX_POS - sizex_v;
            end if;
            if posy_v + sizey_v > C_MAX_POS then
               posy_v := C_MAX_POS - sizey_v;
            end if;

            startx <= to_std_logic_vector(posx_v, 18) xor C_SIGN;
            starty <= to_std_logic_vector(posy_v, 18) xor C_SIGN;
            stepx  <= to_std_logic_vector(stepx_v, 18);
            stepy  <= to_std_logic_vector(stepy_v, 18);
         end if;

         if rst_i = '1' then
            startx <= C_INIT_STARTX;
            starty <= C_INIT_STARTY;
            stepx  <= C_INIT_STEPX;
            stepy  <= C_INIT_STEPY;
         end if;
      end if;
   end process p_view;

   startx_o <= startx;
   starty_o <= starty;
   stepx_o  <= stepx;
   stepy_o  <= stepy;

end architecture rtl;
