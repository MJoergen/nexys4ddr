library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.palette_pkg.all;

-- This is a self-checking testbench for the VGA output (vga.vhd, i.e. pix.vhd,
-- disp.vhd and the palettes in palette_pkg.vhd). It has two phases.
--
-- In the first phase, the display memory is replaced by a constant value, and
-- the first palette is used (the colour is the value), so the colour output is
-- non-zero exactly in the visible area. It checks the timing of 640x480 @ 60 Hz
-- from the VESA standard, in clock cycles (pixels) and lines:
-- * The sync pulses are active low (negative polarity): Both sync signals are
--   high in the visible area, and the sync pulses are low.
-- * Horizontal: 640 visible pixels, front porch 16, sync pulse 96, back porch
--   48, i.e. 800 in total.
-- * Vertical: 480 visible lines, front porch 10, sync pulse 2, back porch 33,
--   i.e. 525 in total.
--
-- In the second phase, the display memory is replaced by a model with the read
-- latency of disp_mem.vhd (three clock cycles), which holds a different value
-- for each pixel, (x + 3*y) mod 512, so all 512 values (including the set,
-- 511) occur on each line. The
-- palette is changed every 120 lines (it is selected by the asynchronous input
-- palette_i), so all four palettes are used. It checks that the colour of each
-- pixel of a frame is the value of that pixel in the selected palette, and
-- black outside the visible area.
--
-- The testbench runs for a little more than two frames, and stops by itself.

entity vga_tb is
end entity vga_tb;

architecture simulation of vga_tb is

   constant C_H_VISIBLE : integer := 640;
   constant C_H_FRONT   : integer := 16;
   constant C_H_SYNC    : integer := 96;
   constant C_H_BACK    : integer := 48;
   constant C_H_TOTAL   : integer := C_H_VISIBLE + C_H_FRONT + C_H_SYNC + C_H_BACK;

   constant C_V_VISIBLE : integer := 480;
   constant C_V_FRONT   : integer := 10;
   constant C_V_SYNC    : integer := 2;
   constant C_V_BACK    : integer := 33;
   constant C_V_TOTAL   : integer := C_V_VISIBLE + C_V_FRONT + C_V_SYNC + C_V_BACK;

   constant C_COLOUR    : std_logic_vector(7 downto 0) := X"A5";

   -- The value in the display memory in the first phase. Palette 0 shows the
   -- lowest 8 bits of the count as the colour.
   constant C_VALUE     : std_logic_vector(8 downto 0) := "0" & C_COLOUR;

   signal clk     : std_logic;
   signal rst     : std_logic := '1';
   signal rd_addr : std_logic_vector(18 downto 0);
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;
   signal vga_col : std_logic_vector(7 downto 0);

   -- The second phase
   signal pattern : boolean := false;
   signal palette : std_logic_vector(1 downto 0) := "00";
   signal rd_data : std_logic_vector(8 downto 0);
   signal mem_d1  : std_logic_vector(8 downto 0);
   signal mem_d2  : std_logic_vector(8 downto 0);
   signal mem_d3  : std_logic_vector(8 downto 0);

   -- The value of the pixel (x, y) in the display memory in the second phase
   function pixel_value (x : integer; y : integer) return std_logic_vector is
   begin
      return std_logic_vector(to_unsigned((x + 3*y) mod 512, 9));
   end function pixel_value;

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   -- The clock is faster than the real one (25 MHz), to keep the simulation
   -- short. Only the number of clock cycles matters.
   p_clk : process
   begin
      clk <= '0', '1' after 1 ns;
      wait for 2 ns;
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
         mem_d1 <= pixel_value(to_integer(unsigned(rd_addr(18 downto 9))),
                               to_integer(unsigned(rd_addr(8 downto 0))));
         mem_d2 <= mem_d1;
         mem_d3 <= mem_d2;
      end if;
   end process p_mem;

   rd_data <= mem_d3 when pattern else C_VALUE;


   ----------------------------
   -- Checking
   ----------------------------

   -- All times are in clock cycles, counted from the start of the simulation.
   -- The checks start after the first falling edge of each sync signal, so the
   -- start of the simulation (with the pipeline not yet filled) is ignored.
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
      if rising_edge(clk) and rst = '0' and not started then
         -- The first values, so that no edges are detected in the first clock
         -- cycle
         started   := true;
         hs_d      := vga_hs;
         vs_d      := vga_vs;
         visible_d := vga_col /= X"00";

      elsif rising_edge(clk) and rst = '0' and pattern then
         -- The second phase. The output at the falling edge of vs is the pixel
         -- (0, 490), see the first phase.
         t := t + 1;
         n := t - t0 + 490*C_H_TOTAL;
         x := n mod C_H_TOTAL;
         y := (n / C_H_TOTAL) mod C_V_TOTAL;

         exp := (others => '0');
         if x < C_H_VISIBLE and y < C_V_VISIBLE then
            exp := palette_colour(std_logic_vector(to_unsigned(y / 120, 2)), pixel_value(x, y));
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
         -- 359 and 360 (after the visible part of the line), and back to the
         -- first palette after the line 479
         if x = 700 and y < C_V_VISIBLE and y mod 120 = 119 then
            palette <= std_logic_vector(to_unsigned((y / 120 + 1) mod 4, 2));
         end if;

         -- Stop after the last visible line of the next frame
         if n = (C_V_TOTAL + C_V_VISIBLE)*C_H_TOTAL then
            assert errors = 0
               report integer'image(errors) & " pixels with the wrong colour"
               severity error;
            report "vga_tb: finished";
            std.env.finish;
         end if;

      elsif rising_edge(clk) and rst = '0' then
         t := t + 1;
         visible := vga_col /= X"00";

         if visible then
            assert vga_col = C_COLOUR
               report "Wrong colour in the visible area" severity error;

            -- The sync pulses are active low, so both are high here
            assert vga_hs = '1' and vga_vs = '1'
               report "Sync signal low in the visible area (the sync pulses " &
                      "must be active low)" severity error;
         end if;

         -- Horizontal sync
         if hs_d = '1' and vga_hs = '0' then
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
         if hs_d = '0' and vga_hs = '1' and hs_fall >= 0 then
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
         if vs_d = '1' and vga_vs = '0' then
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
         if vs_d = '0' and vga_vs = '1' and vs_fall >= 0 then
            assert t - vs_fall = C_V_SYNC*C_H_TOTAL
               report "Wrong vertical sync pulse: " &
                      integer'image(t - vs_fall) & " clock cycles" severity error;
            vs_rise := t;
         end if;

         hs_d      := vga_hs;
         vs_d      := vga_vs;
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
      port map (
         clk_i     => clk,
         rst_i     => rst,
         rd_addr_o => rd_addr,
         rd_data_i => rd_data,
         palette_i => palette,
         vga_hs_o  => vga_hs,
         vga_vs_o  => vga_vs,
         vga_col_o => vga_col
      ); -- i_vga

end architecture simulation;
