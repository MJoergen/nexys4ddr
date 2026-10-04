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
-- dispatcher and the job modules never wrap around. This means:
-- * The left (top) edge is never less than -2. Panning stops there.
-- * The right (bottom) edge, i.e. the value of the last column (row), is never
--   2 or more. Panning stops there.
-- * The size of a pixel is at least one LSB (2^-16). Zooming in stops there.
-- * Zooming keeps the centre of the picture fixed, i.e. the pixel in column
--   G_NUM_COLS/2 and row G_NUM_ROWS/2 (just right of and below the centre of
--   the screen) shows the same point before and after the zoom. When zooming
--   out would move an edge out of range, the view is moved instead, so the
--   edge stays at the end of the range. Zooming out stops when the view can
--   not get any larger.
--
-- Internally the positions are handled in offset binary, i.e. as the value
-- plus 2, which is in the range 0 to 4. This is the 2.16 value with the sign
-- bit inverted, interpreted as an unsigned number.
--
-- The update is calculated over several clock cycles (17, or 18 for 1280
-- columns), one small step at a time, because all of it in a single clock
-- cycle is far too slow for the MAIN clock. The outputs are all changed at the same time, at the
-- end of the update. Pulses on upd_i during an update are ignored.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

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
   constant C_MAX_POS   : natural := 2**18-1;

   -- The smallest size of a pixel (one LSB)
   constant C_MIN_STEP  : natural := 1;

   -- The largest size of a pixel, such that the view from the first to the
   -- last column (row), i.e. step*(num-1), is at most C_MAX_POS.
   constant C_MAX_STEPX : natural := C_MAX_POS / (G_NUM_COLS-1);
   constant C_MAX_STEPY : natural := C_MAX_POS / (G_NUM_ROWS-1);

   -- The column and row of the pixel that is kept fixed when zooming
   constant C_CENTRE_X  : natural := G_NUM_COLS/2;
   constant C_CENTRE_Y  : natural := G_NUM_ROWS/2;

   -- Inverts the sign bit, to convert between 2.16 and offset binary
   constant C_SIGN      : std_logic_vector(17 downto 0) := "10" & X"0000";

   -- Initial view. The positions are in offset binary. They are checked below.
   constant C_INIT_POSX : integer := integer((G_START_X+4.0)*real(2**16)) - 2**17;
   constant C_INIT_POSY : integer := integer((G_START_Y+4.0)*real(2**16)) - 2**17;
   constant C_INIT_DX   : integer := integer(G_SIZE_X*real(2**16))/G_NUM_COLS;
   constant C_INIT_DY   : integer := integer(G_SIZE_Y*real(2**16))/G_NUM_ROWS;

   -- The same in 2.16 format. The values are limited to the range of the
   -- format here, so that an initial view outside the range is reported by the
   -- checks below, and not as an error in the conversion.
   constant C_INIT_STARTX : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(maximum(0, minimum(C_INIT_POSX, C_MAX_POS)), 18) xor C_SIGN;
   constant C_INIT_STARTY : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(maximum(0, minimum(C_INIT_POSY, C_MAX_POS)), 18) xor C_SIGN;
   constant C_INIT_STEPX  : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(maximum(0, minimum(C_INIT_DX, 2**18-1)), 18);
   constant C_INIT_STEPY  : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(maximum(0, minimum(C_INIT_DY, 2**18-1)), 18);

   type t_state is (IDLE_ST, ZOOM_ST, STEP_ST, PREP_ST, MULT_ST, CENTRE_ST,
                    PAN_ST, CLAMP_ST);
   signal state  : t_state := IDLE_ST;

   -- The outputs
   signal startx : std_logic_vector(17 downto 0);
   signal starty : std_logic_vector(17 downto 0);
   signal stepx  : std_logic_vector(17 downto 0);
   signal stepy  : std_logic_vector(17 downto 0);

   -- The new view, while it is calculated
   signal btn      : std_logic_vector( 4 downto 0);
   signal zoom_out : std_logic;
   signal posx     : std_logic_vector(18 downto 0);  -- Offset binary
   signal posy     : std_logic_vector(18 downto 0);
   signal dx       : std_logic_vector(17 downto 0);  -- Size of a pixel
   signal dy       : std_logic_vector(17 downto 0);
   signal deltax   : std_logic_vector(18 downto 0);  -- Change of size when zooming
   signal deltay   : std_logic_vector(18 downto 0);
   signal zoomx    : std_logic_vector(18 downto 0);  -- Size of a pixel after zooming
   signal zoomy    : std_logic_vector(18 downto 0);
   signal zoomed   : std_logic;                      -- The size has been changed

   -- Serial multiplication by the constant number of columns (rows) minus one,
   -- one bit of the constant per clock cycle. The product is subtracted from
   -- C_MAX_POS, which gives the largest position of the first column (row).
   -- The multiplication uses only shifts and subtractions. This makes sure
   -- that synthesis does not use a DSP for it, because they are all used by
   -- the iterators.
   signal multx    : std_logic_vector(28 downto 0);
   signal multy    : std_logic_vector(28 downto 0);
   signal kx       : std_logic_vector(10 downto 0);
   signal ky       : std_logic_vector(10 downto 0);
   signal limx     : std_logic_vector(28 downto 0);
   signal limy     : std_logic_vector(28 downto 0);

   -- Serial multiplication of the change of the size of a pixel (deltax) by
   -- the column (row) of the centre, at the same time as the one above. This
   -- gives the distance the first column (row) must move, to keep the centre
   -- fixed when zooming. This is small: deltax is at most C_MAX_STEPX/64+1, so
   -- offx is less than 2^18.
   signal multdx   : std_logic_vector(18 downto 0);
   signal multdy   : std_logic_vector(18 downto 0);
   signal kcx      : std_logic_vector(10 downto 0);
   signal kcy      : std_logic_vector(10 downto 0);
   signal offx     : std_logic_vector(18 downto 0);
   signal offy     : std_logic_vector(18 downto 0);

begin

   assert G_NUM_COLS <= 2**11 and G_NUM_ROWS <= 2**11
      report "The serial multiplication only supports constants below 2^11"
      severity failure;

   -- The initial view must be inside the range, like the view after every
   -- update: The first column (row) is at least -2, the last column (row) is
   -- less than 2, and the size of a pixel is at least one LSB.
   assert C_INIT_POSX >= 0 and C_INIT_POSY >= 0
      report "The initial view starts below -2"
      severity failure;

   assert C_INIT_DX >= C_MIN_STEP and C_INIT_DY >= C_MIN_STEP
      report "The initial size of a pixel is less than one LSB"
      severity failure;

   assert C_INIT_DX <= C_MAX_STEPX and C_INIT_DY <= C_MAX_STEPY and
          C_INIT_POSX + C_INIT_DX*(G_NUM_COLS-1) <= C_MAX_POS and
          C_INIT_POSY + C_INIT_DY*(G_NUM_ROWS-1) <= C_MAX_POS
      report "The initial view ends at 2 or above"
      severity failure;

   p_view : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case state is
            when IDLE_ST =>
               if upd_i = '1' then
                  btn      <= btn_i;
                  zoom_out <= zoom_out_i;
                  posx     <= "0" & (startx xor C_SIGN);
                  posy     <= "0" & (starty xor C_SIGN);
                  dx       <= stepx;
                  dy       <= stepy;
                  deltax   <= ("0000000" & stepx(17 downto 6)) + 1;
                  deltay   <= ("0000000" & stepy(17 downto 6)) + 1;
                  state    <= ZOOM_ST;
               end if;

            when ZOOM_ST =>
               -- The size of a pixel changes by 1/64 of its value plus one LSB.
               -- When zooming in this is never negative, because dx and dy
               -- are at least one LSB.
               if zoom_out = '1' then
                  zoomx <= ("0" & dx) + deltax;
                  zoomy <= ("0" & dy) + deltay;
               else
                  zoomx <= ("0" & dx) - deltax;
                  zoomy <= ("0" & dy) - deltay;
               end if;
               state <= STEP_ST;

            when STEP_ST =>
               -- Zoom. This is only done if the new view fits in the range.
               zoomed <= '0';
               if btn(4) = '1' and
                  zoomx >= C_MIN_STEP and zoomy >= C_MIN_STEP and
                  zoomx <= C_MAX_STEPX and zoomy <= C_MAX_STEPY
               then
                  dx     <= zoomx(17 downto 0);
                  dy     <= zoomy(17 downto 0);
                  zoomed <= '1';
               end if;
               state <= PREP_ST;

            when PREP_ST =>
               -- Prepare the multiplications
               multx  <= "00000000000" & dx;
               multy  <= "00000000000" & dy;
               kx     <= to_std_logic_vector(G_NUM_COLS-1, 11);
               ky     <= to_std_logic_vector(G_NUM_ROWS-1, 11);
               limx   <= to_std_logic_vector(C_MAX_POS, 29);
               limy   <= to_std_logic_vector(C_MAX_POS, 29);
               multdx <= deltax;
               multdy <= deltay;
               kcx    <= to_std_logic_vector(C_CENTRE_X, 11);
               kcy    <= to_std_logic_vector(C_CENTRE_Y, 11);
               offx   <= (others => '0');
               offy   <= (others => '0');
               state  <= MULT_ST;

            when MULT_ST =>
               -- Calculate limx = C_MAX_POS - dx*(G_NUM_COLS-1), and the same
               -- for y. This is never negative, because dx is at most
               -- C_MAX_STEPX.
               if kx(0) = '1' then
                  limx <= limx - multx;
               end if;
               if ky(0) = '1' then
                  limy <= limy - multy;
               end if;
               multx <= multx(27 downto 0) & "0";
               multy <= multy(27 downto 0) & "0";
               kx    <= "0" & kx(10 downto 1);
               ky    <= "0" & ky(10 downto 1);

               -- Calculate offx = deltax*C_CENTRE_X, and the same for y
               if kcx(0) = '1' then
                  offx <= offx + multdx;
               end if;
               if kcy(0) = '1' then
                  offy <= offy + multdy;
               end if;
               multdx <= multdx(17 downto 0) & "0";
               multdy <= multdy(17 downto 0) & "0";
               kcx    <= "0" & kcx(10 downto 1);
               kcy    <= "0" & kcy(10 downto 1);

               if kx = 0 and ky = 0 and kcx = 0 and kcy = 0 then
                  state <= CENTRE_ST;
               end if;

            when CENTRE_ST =>
               -- Keep the centre fixed when zooming: When the size of a pixel
               -- decreases by deltax (zoom in), the first column moves right
               -- by deltax*C_CENTRE_X, and the other way around (zoom out). It
               -- is never moved to before the start of the range. The right
               -- (bottom) edge is checked at the end.
               if zoomed = '1' then
                  if zoom_out = '0' then
                     posx <= posx + offx;
                     posy <= posy + offy;
                  else
                     if posx >= offx then
                        posx <= posx - offx;
                     else
                        posx <= (others => '0');
                     end if;
                     if posy >= offy then
                        posy <= posy - offy;
                     else
                        posy <= (others => '0');
                     end if;
                  end if;
               end if;
               state <= PAN_ST;

            when PAN_ST =>
               -- Pan. The right button has priority over the left button, and
               -- the down button over the up button.
               if btn(2) = '1' then
                  posx <= posx + dx;
               elsif btn(3) = '1' then
                  if posx >= dx then
                     posx <= posx - dx;
                  else
                     posx <= (others => '0');
                  end if;
               end if;

               if btn(0) = '1' then
                  posy <= posy + dy;
               elsif btn(1) = '1' then
                  if posy >= dy then
                     posy <= posy - dy;
                  else
                     posy <= (others => '0');
                  end if;
               end if;
               state <= CLAMP_ST;

            when CLAMP_ST =>
               -- Keep the right and bottom edges in range. This is needed after
               -- panning right or down, and after zooming out.
               if posx > limx then
                  startx <= limx(17 downto 0) xor C_SIGN;
               else
                  startx <= posx(17 downto 0) xor C_SIGN;
               end if;
               if posy > limy then
                  starty <= limy(17 downto 0) xor C_SIGN;
               else
                  starty <= posy(17 downto 0) xor C_SIGN;
               end if;
               stepx <= dx;
               stepy <= dy;
               state <= IDLE_ST;
         end case;

         if rst_i = '1' then
            startx <= C_INIT_STARTX;
            starty <= C_INIT_STARTY;
            stepx  <= C_INIT_STEPX;
            stepy  <= C_INIT_STEPY;
            state  <= IDLE_ST;
         end if;
      end if;
   end process p_view;

   startx_o <= startx;
   starty_o <= starty;
   stepx_o  <= stepx;
   stepy_o  <= stepy;

end architecture rtl;
