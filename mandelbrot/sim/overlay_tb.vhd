-- This is a self-checking testbench for the frame rate overlay (overlay.vhd),
-- as part of the VGA output (vga.vhd).
--
-- The video mode is 640x480, with the column followed by the row in the
-- address (as on the Nexys 4 DDR). The display memory is replaced by a model
-- with the read latency of disp_mem.vhd (four clock cycles), which holds a
-- different value for each pixel, (x + 3*y) mod 512, as in vga_tb.vhd. The first palette is used, so
-- the colour is the lowest 8 bits of the value. The testbench checks that the
-- colour of each pixel of three frames is either the colour of the picture,
-- or (inside the overlay) the colour of the digit shown there.
--
-- The frame rate is changed twice, each time in the middle of the overlay, in
-- the frame before the one where the new value is expected:
-- * Frame 0: Nothing is shown (the initial value).
-- * Frame 1: 1234, i.e. with four blanked digits.
-- * Frame 2: 90567801, i.e. all eight digits.
-- The overlay of the last frame is printed, for a visual check.
--
-- The testbench stops by itself.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.palette_pkg.all;
use work.font_pkg.all;
use work.video_pkg.all;

entity overlay_tb is
end entity overlay_tb;

architecture simulation of overlay_tb is

   constant C_MODE      : video_mode_t := C_VIDEO_640X480;
   constant C_H_VISIBLE : integer := C_MODE.h_visible;
   constant C_H_TOTAL   : integer := h_total(C_MODE);
   constant C_V_VISIBLE : integer := C_MODE.v_visible;
   constant C_V_TOTAL   : integer := v_total(C_MODE);

   -- Position and size of the overlay, see overlay.vhd
   constant C_DIGITS    : integer := 8;
   constant C_X         : integer := C_H_VISIBLE - 8 - 16*C_DIGITS;
   constant C_Y         : integer := 8;
   constant C_WIDTH     : integer := 16;
   constant C_HEIGHT    : integer := 32;

   constant C_FG        : std_logic_vector(7 downto 0) := X"FF";
   constant C_BG        : std_logic_vector(7 downto 0) := X"00";

   type value_t is record
      digits : std_logic_vector(4*C_DIGITS-1 downto 0);
      blank  : std_logic_vector(C_DIGITS-1 downto 0);
   end record value_t;
   type value_vector is array (natural range <>) of value_t;

   -- The value shown in each frame
   constant C_VALUES    : value_vector(0 to 2) := (
      (digits => X"00000000", blank => "11111111"),
      (digits => X"00001234", blank => "11110000"),
      (digits => X"90567801", blank => "00000000"));

   signal clk        : std_logic;
   signal rst        : std_logic := '1';
   signal rd_addr    : std_logic_vector(18 downto 0);
   signal rd_data    : std_logic_vector(8 downto 0) := (others => '0');
   -- The value read, delayed by 1 to 3 clock cycles
   type mem_vector is array (1 to 3) of std_logic_vector(8 downto 0);
   signal mem_d      : mem_vector := (others => (others => '0'));
   signal vga_hs     : std_logic;
   signal vga_vs     : std_logic;
   signal vga_col    : std_logic_vector(7 downto 0);

   signal fps_digits : std_logic_vector(4*C_DIGITS-1 downto 0) := C_VALUES(0).digits;
   signal fps_blank  : std_logic_vector(C_DIGITS-1 downto 0) := C_VALUES(0).blank;

   -- The value of the pixel (x, y) in the display memory
   function pixel_value (x : integer; y : integer) return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned((x + 3*y) mod 512, 9));
   end function pixel_value;

   -- The expected colour of the pixel (x, y) in the visible area, when the
   -- value v is shown
   function expected (x : integer; y : integer; v : value_t) return std_logic_vector is
      variable pos   : integer;
      variable digit : integer;
      variable row   : std_logic_vector(C_WIDTH-1 downto 0);
   begin
      if x >= C_X and x < C_X + C_DIGITS*C_WIDTH and y >= C_Y and y < C_Y + C_HEIGHT then
         -- pos is the position of the digit, 0 is the least significant one
         pos := C_DIGITS-1 - (x - C_X) / C_WIDTH;
         if v.blank(pos) = '0' then
            digit := to_integer(unsigned(v.digits(4*pos+3 downto 4*pos)));
            row   := C_FONT(32*digit + y - C_Y);
            if row(C_WIDTH-1 - (x - C_X) mod C_WIDTH) = '1' then
               return C_FG;
            else
               return C_BG;
            end if;
         end if;
      end if;
      return palette_colour("00", pixel_value(x, y));
   end function expected;

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   -- The clock is faster than the real one (25 MHz), to keep the simulation
   -- short. Only the number of clock cycles matters.
   p_clk : process
   begin
      clk <= '0', '1' after 500 ps;
      wait for 1 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 20 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   ----------------------------
   -- Model of the display memory
   ----------------------------

   p_mem : process (clk)
   begin
      if rising_edge(clk) then
         mem_d(1) <= pixel_value(to_integer(unsigned(rd_addr(18 downto 9))),
                                 to_integer(unsigned(rd_addr(8 downto 0))));
         mem_d(2 to 3) <= mem_d(1 to 2);
         rd_data  <= mem_d(3);
      end if;
   end process p_mem;


   ----------------------------
   -- Checking
   ----------------------------

   -- The checks start at the first falling edge of vs. The output at this
   -- time is the pixel (0, 490), see vga_tb.vhd.
   p_check : process (clk)
      variable started : boolean := false;
      variable vs_d    : std_logic := '1';
      variable n       : integer;          -- Pixel number from (0, 0) of frame 0
      variable x       : integer;
      variable y       : integer;
      variable frame   : integer;
      variable exp     : std_logic_vector(7 downto 0);
      variable errors  : integer := 0;
      variable line    : string(1 to C_DIGITS*C_WIDTH);
   begin
      if rising_edge(clk) and rst = '0' then
         if not started then
            if vs_d = '1' and vga_vs = '0' then
               started := true;
               n := 490*C_H_TOTAL - C_V_TOTAL*C_H_TOTAL;
            end if;
            vs_d := vga_vs;
         else
            n := n + 1;
         end if;

         if started and n >= 0 then
            x     := n mod C_H_TOTAL;
            y     := (n / C_H_TOTAL) mod C_V_TOTAL;
            frame := n / (C_H_TOTAL*C_V_TOTAL);

            exp := (others => '0');
            if x < C_H_VISIBLE and y < C_V_VISIBLE then
               exp := expected(x, y, C_VALUES(frame));
            end if;
            if vga_col /= exp then
               if errors < 10 then
                  report "Wrong colour in frame " & integer'image(frame) &
                         " at (" & integer'image(x) & ", " & integer'image(y) &
                         "): got " & integer'image(to_integer(unsigned(vga_col))) &
                         ", expected " & integer'image(to_integer(unsigned(exp)))
                     severity error;
               end if;
               errors := errors + 1;
            end if;

            -- Print the overlay of the last frame
            if frame = 2 and y >= C_Y and y < C_Y + C_HEIGHT and
               x >= C_X and x < C_X + C_DIGITS*C_WIDTH then
               if vga_col = C_FG then
                  line(x - C_X + 1) := '#';
               elsif vga_col = C_BG then
                  line(x - C_X + 1) := '.';
               else
                  line(x - C_X + 1) := ' ';
               end if;
               if x = C_X + C_DIGITS*C_WIDTH - 1 then
                  report line;
               end if;
            end if;

            -- Stop after the last visible line of frame 2
            if frame = 2 and x = C_H_VISIBLE and y = C_V_VISIBLE-1 then
               assert errors = 0
                  report integer'image(errors) & " pixels with the wrong colour"
                  severity error;
               report "overlay_tb: finished";
               std.env.finish;
            end if;
         end if;
      end if;
   end process p_check;


   -- Change the frame rate in the middle of the overlay, in the frame before
   -- the one where it is expected. The frame rate is changed twice in frame 0,
   -- and only the last change must be shown in frame 1. The inputs are in the
   -- VGA clock domain, as from the synchronizer in nexys4ddr.vhd.
   p_fps : process
      procedure set_value (v : value_t) is
      begin
         fps_digits <= v.digits;
         fps_blank  <= v.blank;
      end procedure set_value;

      procedure wait_line (y : integer) is
      begin
         -- The pixel counters are not visible here, so wait for the falling
         -- edge of hs, which is in the line y of the output when the line
         -- counter is y.
         for i in 1 to y loop
            wait until falling_edge(vga_hs);
         end loop;
      end procedure wait_line;
   begin
      -- Wait for the end of the vertical sync pulse before frame 0, which is
      -- 33 lines before the first line
      wait until rising_edge(vga_vs);
      wait_line(33 + 20);
      set_value((digits => X"00000077", blank => "11111100"));
      wait_line(100);
      set_value(C_VALUES(1));
      wait until rising_edge(vga_vs);
      wait_line(33 + 20);
      set_value(C_VALUES(2));
      wait;
   end process p_fps;


   -------------------
   -- Instantiate DUT
   -------------------

   i_vga : entity work.vga
      generic map (
         G_MODE       => C_MODE,
         G_COL_STRIDE => 512
      )
      port map (
         clk_i        => clk,
         rst_i        => rst,
         rd_addr_o    => rd_addr,
         rd_data_i    => rd_data,
         palette_i    => "00",
         fps_digits_i => fps_digits,
         fps_blank_i  => fps_blank,
         vga_hs_o     => vga_hs,
         vga_vs_o     => vga_vs,
         vga_col_o    => vga_col
      ); -- i_vga

end architecture simulation;
