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
--
-- The update is calculated over several clock cycles (about 16), one small
-- step at a time, because all of it in a single clock cycle is far too slow
-- for the MAIN clock. The outputs are all changed at the same time, at the
-- end of the update. Pulses on upd_i during an update are ignored.

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

   -- Inverts the sign bit, to convert between 2.16 and offset binary
   constant C_SIGN      : std_logic_vector(17 downto 0) := "10" & X"0000";

   -- Initial values, in 2.16 format
   constant C_INIT_STARTX : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer((G_START_X+4.0)*real(2**16)), 18);
   constant C_INIT_STARTY : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer((G_START_Y+4.0)*real(2**16)), 18);
   constant C_INIT_STEPX  : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer(G_SIZE_X*real(2**16))/G_NUM_COLS, 18);
   constant C_INIT_STEPY  : std_logic_vector(17 downto 0) :=
      to_std_logic_vector(integer(G_SIZE_Y*real(2**16))/G_NUM_ROWS, 18);

   type t_state is (IDLE_ST, ZOOM_ST, STEP_ST, PAN_ST, MULT_ST, CLAMP_ST);
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

begin

   assert G_NUM_COLS <= 2**11 and G_NUM_ROWS <= 2**11
      report "The serial multiplication only supports constants below 2^11"
      severity failure;

   assert C_INIT_STEPX <= C_MAX_STEPX and C_INIT_STEPY <= C_MAX_STEPY
      report "The initial view is outside the range -2 to 2"
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
               if btn(4) = '1' and
                  zoomx >= C_MIN_STEP and zoomy >= C_MIN_STEP and
                  zoomx <= C_MAX_STEPX and zoomy <= C_MAX_STEPY
               then
                  dx <= zoomx(17 downto 0);
                  dy <= zoomy(17 downto 0);
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

               -- Prepare the multiplication
               multx <= "00000000000" & dx;
               multy <= "00000000000" & dy;
               kx    <= to_std_logic_vector(G_NUM_COLS-1, 11);
               ky    <= to_std_logic_vector(G_NUM_ROWS-1, 11);
               limx  <= to_std_logic_vector(C_MAX_POS, 29);
               limy  <= to_std_logic_vector(C_MAX_POS, 29);
               state <= MULT_ST;

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

               if kx = 0 and ky = 0 then
                  state <= CLAMP_ST;
               end if;

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
