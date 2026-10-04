library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.palette_pkg.all;
use work.video_pkg.all;

-- This is a self-checking testbench for the VGA output (vga.vhd, i.e. pix.vhd,
-- disp.vhd and the palettes in palette_pkg.vhd). It is done for both video
-- modes (see video_pkg.vhd), each with its own instance, and the address
-- layout of the board that uses it: 640x480 with the column followed by the
-- row in 19 bits (as on the Nexys 4 DDR), and 1280x1024 with the column
-- followed by the row in 21 bits (as on the MEGA65 R6). A third instance
-- checks 640x480 with 480 addresses per column, i.e. an address distance
-- between columns which is not a power of two. Each instance has two phases.
--
-- In the first phase, the display memory is replaced by a constant value, and
-- the first palette is used (the colour is the value), so the colour output is
-- non-zero exactly in the visible area. It checks the timing of the video mode
-- from the VESA standard, in clock cycles (pixels) and lines:
-- * The polarity of the sync pulses: Both sync signals are inactive in the
--   visible area, and active during the sync pulses (low for 640x480, high
--   for 1280x1024).
-- * Horizontal: the visible pixels, front porch, sync pulse and back porch,
--   e.g. 640, 16, 96 and 48, i.e. 800 in total for 640x480.
-- * Vertical: the visible lines, front porch, sync pulse and back porch, e.g.
--   480, 10, 2 and 33, i.e. 525 in total for 640x480.
--
-- In the second phase, the display memory is replaced by a model with the read
-- latency of disp_mem.vhd (four clock cycles), which holds a different value
-- for each pixel, (x + 3*y) mod 512, so all 512 values (including the set,
-- 511) occur on each line. This also checks the address of each pixel. The
-- palette is changed every 120 lines (it is selected by the asynchronous input
-- palette_i), so all four palettes are used. It checks that the colour of each
-- pixel of a frame is the value of that pixel in the selected palette, and
-- black outside the visible area.
--
-- The frame rate overlay (overlay.vhd) is switched off here (all digits are
-- blanked), it is tested by overlay_tb.vhd.
--
-- Each instance runs for a little more than two frames, and the testbench
-- stops by itself.

entity vga_tb is
end entity vga_tb;

architecture simulation of vga_tb is

   type config_t is record
      mode       : video_mode_t;
      col_stride : integer;      -- Address distance between two columns
      addr_bits  : integer;      -- Bits of the address
   end record config_t;
   type config_vector is array (natural range <>) of config_t;

   constant C_CONFIGS : config_vector := (
      (mode => C_VIDEO_640X480,   col_stride =>  512, addr_bits => 19),
      (mode => C_VIDEO_1280X1024, col_stride => 1024, addr_bits => 21),
      (mode => C_VIDEO_640X480,   col_stride =>  480, addr_bits => 19));

   constant C_COLOUR    : std_logic_vector(7 downto 0) := X"A5";

   -- The value in the display memory in the first phase. Palette 0 shows the
   -- lowest 8 bits of the count as the colour.
   constant C_VALUE     : std_logic_vector(8 downto 0) := "0" & C_COLOUR;

   -- The value of the pixel (x, y) in the display memory in the second phase
   function pixel_value (x : integer; y : integer) return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned((x + 3*y) mod 512, 9));
   end function pixel_value;

   signal clk      : std_logic;
   signal rst      : std_logic := '1';
   signal finished : std_logic_vector(C_CONFIGS'range) := (others => '0');

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   -- The clock is faster than the real one (25 MHz or 108 MHz), to keep the
   -- simulation short. Only the number of clock cycles matters.
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

   p_finish : process
   begin
      wait until finished = (finished'range => '1');
      report "vga_tb: finished";
      std.env.finish;
   end process p_finish;


   gen_config : for m in C_CONFIGS'range generate
      constant C_MODE      : video_mode_t := C_CONFIGS(m).mode;
      constant C_STRIDE    : integer := C_CONFIGS(m).col_stride;
      constant C_ADDR_BITS : integer := C_CONFIGS(m).addr_bits;
      -- The read latency of the display memory
      constant C_LATENCY   : integer := 4;

      constant C_H_VISIBLE : integer := C_MODE.h_visible;
      constant C_H_FRONT   : integer := C_MODE.h_front;
      constant C_H_SYNC    : integer := C_MODE.h_sync;
      constant C_H_BACK    : integer := C_MODE.h_back;
      constant C_H_TOTAL   : integer := C_H_VISIBLE + C_H_FRONT + C_H_SYNC + C_H_BACK;

      constant C_V_VISIBLE : integer := C_MODE.v_visible;
      constant C_V_FRONT   : integer := C_MODE.v_front;
      constant C_V_SYNC    : integer := C_MODE.v_sync;
      constant C_V_BACK    : integer := C_MODE.v_back;
      constant C_V_TOTAL   : integer := C_V_VISIBLE + C_V_FRONT + C_V_SYNC + C_V_BACK;

      signal rd_addr : std_logic_vector(C_ADDR_BITS-1 downto 0);
      signal vga_hs  : std_logic;
      signal vga_vs  : std_logic;
      signal vga_col : std_logic_vector(7 downto 0);

      -- The sync signals, low during the sync pulse, whatever the polarity
      signal hs_n    : std_logic;
      signal vs_n    : std_logic;

      -- The second phase
      signal pattern : boolean := false;
      signal palette : std_logic_vector(1 downto 0) := "00";
      signal rd_data : std_logic_vector(8 downto 0);
      -- The value read, delayed by 1 to C_LATENCY clock cycles
      type mem_vector is array (1 to C_LATENCY) of std_logic_vector(8 downto 0);
      signal mem_d   : mem_vector;

   begin

      ----------------------------
      -- Model of the display memory
      ----------------------------

      p_mem : process (clk)
      begin
         if rising_edge(clk) then
            mem_d(1) <= pixel_value(to_integer(unsigned(rd_addr)) / C_STRIDE,
                                    to_integer(unsigned(rd_addr)) mod C_STRIDE);
            mem_d(2 to C_LATENCY) <= mem_d(1 to C_LATENCY-1);
         end if;
      end process p_mem;

      rd_data <= mem_d(C_LATENCY) when pattern else C_VALUE;

      hs_n <= vga_hs xor C_MODE.sync_active;
      vs_n <= vga_vs xor C_MODE.sync_active;


      ----------------------------
      -- Checking
      ----------------------------

      -- All times are in clock cycles, counted from the start of the
      -- simulation. The checks start after the first sync pulse of each sync
      -- signal (the first falling edge of hs_n and vs_n), so the start of the
      -- simulation (with the pipeline not yet filled) is ignored.
      p_check : process (clk)
         variable started    : boolean := false;
         variable t          : integer := 0;
         variable hs_d       : std_logic;
         variable vs_d       : std_logic;
         variable visible_d  : boolean;

         variable hs_fall    : integer := -1;   -- Time of the last falling edge
         variable hs_rise    : integer := -1;   -- Time of the last rising edge
         variable vs_fall    : integer := -1;
         variable vs_rise    : integer := -1;
         variable vis_start  : integer := -1;   -- Start of the last visible line
         variable vis_end    : integer := -1;   -- End of the last visible line
         variable last_line  : integer := -1;   -- Start of the last visible line before vs_fall
         variable lines      : integer := 0;    -- Visible lines in this frame
         variable frames     : integer := 0;    -- Frames checked
         variable visible    : boolean;

         -- The second phase
         variable t0         : integer;         -- Time of the falling edge of vs
         variable n          : integer;         -- Pixel number from (0, 0)
         variable x          : integer;
         variable y          : integer;
         variable exp        : std_logic_vector(7 downto 0);
         variable errors     : integer := 0;
      begin
         if finished(m) = '1' then
            -- This instance is finished, and waits for the others
            null;

         elsif rising_edge(clk) and rst = '0' and not started then
            -- The first values, so that no edges are detected in the first clock
            -- cycle
            started   := true;
            hs_d      := hs_n;
            vs_d      := vs_n;
            visible_d := vga_col /= X"00";

         elsif rising_edge(clk) and rst = '0' and pattern then
            -- The second phase. The output at the start of the vertical sync
            -- pulse is the pixel (0, C_V_VISIBLE + C_V_FRONT), see the first
            -- phase.
            t := t + 1;
            n := t - t0 + (C_V_VISIBLE + C_V_FRONT)*C_H_TOTAL;
            x := n mod C_H_TOTAL;
            y := (n / C_H_TOTAL) mod C_V_TOTAL;

            exp := (others => '0');
            if x < C_H_VISIBLE and y < C_V_VISIBLE then
               exp := palette_colour(std_logic_vector(to_unsigned((y / 120) mod 4, 2)),
                                     pixel_value(x, y));
            end if;
            if vga_col /= exp then
               if errors < 10 then
                  report "Wrong colour at (" & integer'image(x) & ", " &
                         integer'image(y) & "): got " &
                         integer'image(to_integer(unsigned(vga_col))) &
                         ", expected " & integer'image(to_integer(unsigned(exp)))
                     severity error;
               end if;
               errors := errors + 1;
            end if;

            -- Change the palette between the lines 119 and 120, 239 and 240, and
            -- so on (after the visible part of the line), and back to the first
            -- palette after the last visible line
            if x = C_H_VISIBLE + 60 and y < C_V_VISIBLE and y mod 120 = 119 then
               palette <= std_logic_vector(to_unsigned((y / 120 + 1) mod 4, 2));
               if y = C_V_VISIBLE-1 then
                  palette <= "00";
               end if;
            end if;

            -- Stop after the last visible line of the next frame
            if n = (C_V_TOTAL + C_V_VISIBLE)*C_H_TOTAL then
               assert errors = 0
                  report integer'image(errors) & " pixels with the wrong colour"
                  severity error;
               report integer'image(C_H_VISIBLE) & "x" & integer'image(C_V_VISIBLE) &
                      ": finished";
               finished(m) <= '1';
            end if;

         elsif rising_edge(clk) and rst = '0' then
            t := t + 1;
            visible := vga_col /= X"00";

            if visible then
               assert vga_col = C_COLOUR
                  report "Wrong colour in the visible area" severity error;

               -- Both sync signals are inactive here
               assert hs_n = '1' and vs_n = '1'
                  report "Sync signal active in the visible area (wrong " &
                         "polarity of the sync pulses)" severity error;
            end if;

            -- Horizontal sync
            if hs_d = '1' and hs_n = '0' then
               if hs_fall >= 0 then
                  assert t - hs_fall = C_H_TOTAL
                     report "Wrong time between horizontal sync pulses: " &
                            integer'image(t - hs_fall) severity error;
               end if;
               if vis_end >= 0 and vis_end > hs_rise then
                  assert t - vis_end = C_H_FRONT
                     report "Wrong horizontal front porch: " &
                            integer'image(t - vis_end) severity error;
               end if;
               hs_fall := t;
            end if;
            if hs_d = '0' and hs_n = '1' and hs_fall >= 0 then
               assert t - hs_fall = C_H_SYNC
                  report "Wrong horizontal sync pulse: " &
                         integer'image(t - hs_fall) severity error;
               hs_rise := t;
            end if;

            -- Visible area
            if visible and not visible_d then
               if hs_rise >= 0 and hs_rise > vis_end then
                  assert t - hs_rise = C_H_BACK
                     report "Wrong horizontal back porch: " &
                            integer'image(t - hs_rise) severity error;
               end if;
               if vs_rise >= 0 and vs_rise > last_line then
                  assert t - vs_rise = C_V_BACK*C_H_TOTAL
                     report "Wrong vertical back porch: " &
                            integer'image(t - vs_rise) & " clock cycles" severity error;
               end if;
               -- The first line may have started before the checks
               if hs_fall >= 0 then
                  vis_start := t;
               else
                  vis_start := -1;
               end if;
               last_line := t;
               lines     := lines + 1;
            end if;
            if visible_d and not visible then
               if vis_start >= 0 then
                  assert t - vis_start = C_H_VISIBLE
                     report "Wrong number of visible pixels: " &
                            integer'image(t - vis_start) severity error;
               end if;
               vis_end := t;
            end if;

            -- Vertical sync
            if vs_d = '1' and vs_n = '0' then
               if vs_fall >= 0 then
                  assert t - vs_fall = C_V_TOTAL*C_H_TOTAL
                     report "Wrong time between vertical sync pulses: " &
                            integer'image(t - vs_fall) severity error;
                  assert lines = C_V_VISIBLE
                     report "Wrong number of visible lines: " &
                            integer'image(lines) severity error;
                  assert t - last_line = (C_V_FRONT+1)*C_H_TOTAL
                     report "Wrong vertical front porch: " &
                            integer'image(t - last_line) & " clock cycles" severity error;
                  frames := frames + 1;
               end if;
               vs_fall := t;
               lines   := 0;
            end if;
            if vs_d = '0' and vs_n = '1' and vs_fall >= 0 then
               assert t - vs_fall = C_V_SYNC*C_H_TOTAL
                  report "Wrong vertical sync pulse: " &
                         integer'image(t - vs_fall) & " clock cycles" severity error;
               vs_rise := t;
            end if;

            hs_d      := hs_n;
            vs_d      := vs_n;
            visible_d := visible;

            if frames = 1 then
               assert vs_rise > 0 and hs_rise > 0
                  report "Sync pulses not seen" severity error;

               -- Start the second phase, at the falling edge of vs
               pattern <= true;
               palette <= "00";
               t0      := t;
            end if;
         end if;
      end process p_check;


      -------------------
      -- Instantiate DUT
      -------------------

      i_vga : entity work.vga
         generic map (
            G_MODE       => C_MODE,
            G_COL_STRIDE => C_STRIDE,
            G_ADDR_BITS  => C_ADDR_BITS
         )
         port map (
            clk_i     => clk,
            rst_i     => rst,
            rd_addr_o => rd_addr,
            rd_data_i => rd_data,
            palette_i => palette,
            fps_digits_i => (others => '0'),
            fps_blank_i  => (others => '1'),
            vga_hs_o  => vga_hs,
            vga_vs_o  => vga_vs,
            vga_col_o => vga_col
         ); -- i_vga

   end generate gen_config;

end architecture simulation;
