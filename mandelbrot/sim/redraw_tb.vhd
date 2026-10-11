-- This is a self-checking testbench for main.vhd, which checks that a picture
-- is only calculated when the view has changed, i.e. after reset, and after
-- an update of the view that changes it:
-- * When a picture is started, the view differs from the view of the previous
--   picture, i.e. no picture is calculated twice (p_check).
-- * At each update of the view (upd in main.vhd), the latest picture is
--   finished, and its view is the current view, i.e. every change of the view
--   has given a new picture (p_check). An update takes 17 clock cycles, and a
--   picture at most about 2200 (reported at the end), less than the time
--   between two updates, so the picture of an update is finished before the
--   next update.
-- * Each picture writes exactly the number of words of a picture, and nothing
--   is written between the pictures.
-- * The frame rate is updated once for each picture.
-- * No picture is started while the display memory (disp_mem.vhd) is being
--   filled after reset, because it ignores the writes then. After the first
--   picture, and after the last one, every pixel of the picture in the display
--   memory, read on its read port, is the value written by main. Before main
--   waited for the display memory, the first picture was started at once, and
--   most of it was lost.
-- The buttons are held down for exactly one update at a time, so the view
-- changes at most once between two pictures. The updates are: none (so the
-- view does not change, and nothing must be written), pan right, zoom in, zoom
-- out, and pan left until the left edge of the view is at -2 and the view
-- does not change any more.
--
-- The update pulse, the start of a picture, and the view are inside main.vhd,
-- so they are read with external names. A small picture with a few job modules
-- and a small display memory (8 blocks, which takes 16384 clock cycles to fill)
-- are used, and the update rate (G_CLK_FREQ/18) is much higher than on the
-- board, to keep the simulation short.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity redraw_tb is
end entity redraw_tb;

architecture simulation of redraw_tb is

   constant C_NUM_ITERATORS : positive := 5;
   constant C_PIXELS        : positive := 2;
   constant C_ROWS_IN_JOB   : positive := 6;
   constant C_NUM_COLS      : positive := 16;
   constant C_NUM_ROWS      : positive := 12;
   constant C_COL_STRIDE    : positive := 16;
   -- The display memory has 8 blocks of 4096 pixels, i.e. a single group of
   -- blocks. The address has one bit more than this needs, as in
   -- disp_mem_tb, because otherwise the number of the group has no bits,
   -- which gives warnings in disp_mem.vhd.
   constant C_MEM_BLOCKS    : positive := 8;
   constant C_ADDR_BITS     : positive := 16;
   -- The read latency of the display memory
   constant C_RD_LAT        : positive := 4;

   -- The number of words written for each picture
   constant C_WORDS         : positive := C_NUM_COLS*C_NUM_ROWS/C_PIXELS;

   -- Clock cycles between two updates of the view. main.vhd updates the view
   -- 18 times per second, i.e. every G_CLK_FREQ/18 clock cycles. This must be
   -- longer than a picture.
   constant C_UPD_PERIOD    : positive := 4000;

   -- Clock cycles to wait for an update of the view to finish
   constant C_UPD_CYCLES    : positive := 32;

   -- The view, i.e. startx, starty, stepx, and stepy
   subtype t_view is std_logic_vector(71 downto 0);

   signal clk       : std_logic;
   signal rst       : std_logic := '1';

   signal btn       : std_logic_vector(4 downto 0) := "00000";
   signal sw        : std_logic_vector(7 downto 0) := X"00";

   signal fps_valid : std_logic;
   signal wr_addr   : std_logic_vector(C_ADDR_BITS-1 downto 0);
   signal wr_data   : std_logic_vector(9*C_PIXELS-1 downto 0);
   signal wr_en     : std_logic;
   signal wr_busy   : std_logic;
   signal rd_addr   : std_logic_vector(C_ADDR_BITS-1 downto 0) := (others => '0');
   signal rd_data   : std_logic_vector(8 downto 0);

   -- The latest value written by main to each pixel of the picture
   type t_pixels is array (0 to C_NUM_COLS*C_COL_STRIDE-1) of std_logic_vector(8 downto 0);
   signal written   : t_pixels;

   -- Counted by p_check: the pictures started, the pictures finished (all
   -- their words written), the words written, the updates of the frame rate,
   -- and the longest time from the start of a picture until its last word is
   -- written (in clock cycles)
   signal pictures  : natural := 0;
   signal finished  : natural := 0;
   signal writes    : natural := 0;
   signal fps_count : natural := 0;
   signal max_time  : natural := 0;

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   -------------------
   -- Instantiate DUT
   -------------------

   i_main : entity work.main
      generic map (
         G_CLK_FREQ      => 18*C_UPD_PERIOD,
         G_NUM_ITERATORS => C_NUM_ITERATORS,
         G_PIXELS        => C_PIXELS,
         G_ROWS_IN_JOB   => C_ROWS_IN_JOB,
         G_NUM_COLS      => C_NUM_COLS,
         G_NUM_ROWS      => C_NUM_ROWS,
         G_COL_STRIDE    => C_COL_STRIDE,
         G_ADDR_BITS     => C_ADDR_BITS
      )
      port map (
         clk_i        => clk,
         rst_i        => rst,
         btn_i        => btn,
         sw_i         => sw,
         seg_o        => open,
         seg_an_o     => open,
         fps_digits_o => open,
         fps_blank_o  => open,
         fps_valid_o  => fps_valid,
         wr_addr_o    => wr_addr,
         wr_data_o    => wr_data,
         wr_en_o      => wr_en,
         wr_busy_i    => wr_busy
      ); -- i_main

   -- The same display memory as on the MEGA65 (no write registers for the
   -- blocks), but with only 8 blocks. The read port uses the same clock.
   i_disp_mem : entity work.disp_mem
      generic map (
         G_ADDR_BITS  => C_ADDR_BITS,
         G_NUM_BLOCKS => C_MEM_BLOCKS,
         G_BLOCK_REGS => false,
         G_PIXELS     => C_PIXELS
      )
      port map (
         wr_clk_i     => clk,
         wr_rst_i     => rst,
         wr_addr_i    => wr_addr,
         wr_data_i    => wr_data,
         wr_en_i      => wr_en,
         wr_busy_o    => wr_busy,
         rd_clk_i     => clk,
         rd_rst_i     => '0',
         rd_addr_i    => rd_addr,
         rd_data_o    => rd_data
      ); -- i_disp_mem


   -- The external names must come after the instantiation of main
   b_test : block
      alias upd    is << signal .redraw_tb.i_main.upd    : std_logic >>;
      alias start  is << signal .redraw_tb.i_main.start  : std_logic >>;
      alias startx is << signal .redraw_tb.i_main.startx : std_logic_vector(17 downto 0) >>;
      alias starty is << signal .redraw_tb.i_main.starty : std_logic_vector(17 downto 0) >>;
      alias stepx  is << signal .redraw_tb.i_main.stepx  : std_logic_vector(17 downto 0) >>;
      alias stepy  is << signal .redraw_tb.i_main.stepy  : std_logic_vector(17 downto 0) >>;

      signal view  : t_view;
   begin

      view <= startx & starty & stepx & stepy;

      -------------------------------------------
      -- Check the pictures, at each rising edge
      -------------------------------------------

      p_check : process (clk)
         variable pic_view  : t_view;    -- The view of the latest picture
         variable pic_words : natural;   -- Words written by the latest picture
         variable pic_time  : natural;   -- Clock cycles since the start
      begin
         if rising_edge(clk) and rst = '0' then
            pic_time := pic_time + 1;
            if wr_en = '1' then
               assert pictures > 0 and pic_words < C_WORDS
                  report "A word was written, but no picture is being calculated"
                  severity error;
               assert to_integer(wr_addr) + C_PIXELS <= t_pixels'length
                  report "A word was written outside the picture"
                  severity failure;
               for i in 0 to C_PIXELS-1 loop
                  written(to_integer(wr_addr) + i) <= wr_data(9*i+8 downto 9*i);
               end loop;
               pic_words := pic_words + 1;
               writes    <= writes + 1;
               if pic_words = C_WORDS then
                  finished <= finished + 1;
                  if pic_time > max_time then
                     max_time <= pic_time;
                  end if;
               end if;
            end if;

            if fps_valid = '1' then
               fps_count <= fps_count + 1;
            end if;

            -- The dispatcher takes the view when it sees the start, i.e. at
            -- this rising edge.
            if start = '1' then
               assert wr_busy = '0'
                  report "A picture was started while the display memory was being filled"
                  severity error;
               if pictures > 0 then
                  assert pic_words = C_WORDS
                     report "A picture was started before the previous one was finished"
                     severity error;
                  assert view /= pic_view
                     report "A picture was started, but the view has not changed"
                     severity error;
               end if;
               pic_view  := view;
               pic_words := 0;
               pic_time  := 0;
               pictures  <= pictures + 1;
            end if;

            -- The view module sees the update at this rising edge, so view is
            -- the view before the update. The first picture is started after
            -- the display memory has been filled, which takes several updates,
            -- so this is only checked from the first finished picture.
            if upd = '1' and finished > 0 then
               assert pictures > 0 and pic_words = C_WORDS
                  report "The picture is not finished at the next update"
                  severity error;
               assert view = pic_view
                  report "The view has changed, but no picture was calculated"
                  severity error;
            end if;
         end if;
      end process p_check;


      --------------
      -- Stimulus
      --------------

      p_test : process
         -- The number of updates that changed the view
         variable changes : natural := 0;
         variable changed : boolean;

         -- Hold the buttons down (and switch 2, zoom out) for exactly one
         -- update. They are set long before the update (at least two clock
         -- cycles, because main.vhd registers them), and released after it.
         -- changed is set if the update changed the view.
         procedure do_update (
            b        : std_logic_vector(4 downto 0);
            zoom_out : std_logic := '0'
         ) is
            variable old_v : t_view;
         begin
            btn   <= b;
            sw(2) <= zoom_out;
            wait until rising_edge(clk) and upd = '1';
            old_v := view;
            for i in 1 to C_UPD_CYCLES loop
               wait until rising_edge(clk);
            end loop;
            btn   <= "00000";
            sw(2) <= '0';
            changed := view /= old_v;
            if changed then
               changes := changes + 1;
            end if;
         end procedure do_update;

         -- Read every pixel of the picture from the display memory, and
         -- compare it with the value written by main. The address is held for
         -- longer than the read latency.
         procedure check_memory (name : string) is
            variable addr   : natural;
            variable errors : natural := 0;
         begin
            for col in 0 to C_NUM_COLS-1 loop
               for row in 0 to C_NUM_ROWS-1 loop
                  addr    := col*C_COL_STRIDE + row;
                  rd_addr <= to_slv(addr, C_ADDR_BITS);
                  for i in 1 to C_RD_LAT+2 loop
                     wait until rising_edge(clk);
                  end loop;
                  if rd_data /= written(addr) then
                     if errors < 5 then
                        report "Display memory, " & name & ": pixel in column " &
                               integer'image(col) & ", row " & integer'image(row) &
                               " is " & integer'image(to_integer(rd_data)) &
                               ", but main wrote " & integer'image(to_integer(written(addr)))
                           severity error;
                     end if;
                     errors := errors + 1;
                  end if;
               end loop;
            end loop;
            assert errors = 0
               report "Display memory, " & name & ": " & integer'image(errors) &
                      " of " & integer'image(C_NUM_COLS*C_NUM_ROWS) & " pixels are wrong"
               severity error;
         end procedure check_memory;

         variable pictures_v : natural;
         variable writes_v   : natural;
         variable stopped    : boolean;

      begin
         wait until rst = '0';

         -- The first picture after reset. It is started when the display
         -- memory has been filled, and p_check checks at the next update that
         -- it has the current view.
         wait until finished = 1 for 2 * C_MEM_BLOCKS*4096/C_PIXELS * 10 ns;
         assert finished = 1
            report "The first picture is not finished"
            severity failure;
         check_memory("first picture");
         do_update("00000");
         assert pictures = 1 and writes = C_WORDS
            report "There is not exactly one picture after reset"
            severity error;

         -- Without buttons the view does not change, and nothing is written
         for i in 1 to 3 loop
            do_update("00000");
            assert not changed
               report "The view changed without buttons"
               severity error;
         end loop;
         assert pictures = 1 and writes = C_WORDS
            report "A picture was calculated without a change of the view"
            severity error;

         -- Pan right, zoom in, and zoom out. Each must change the view.
         do_update("00100");
         assert changed report "Pan right did not change the view" severity error;
         do_update("10000");
         assert changed report "Zoom in did not change the view" severity error;
         do_update("10000", '1');
         assert changed report "Zoom out did not change the view" severity error;

         -- Pan left until the left edge of the view is at -2. After that the
         -- view does not change, so no pictures are calculated, although the
         -- button is held down. The update just after the last change checks
         -- the last picture.
         stopped := false;
         for i in 1 to 10 loop
            do_update("01000");
            if not changed and not stopped then
               stopped    := true;
               pictures_v := pictures;
               writes_v   := writes;
            end if;
            assert changed or not stopped or (pictures = pictures_v and writes = writes_v)
               report "A picture was calculated at the left edge"
               severity error;
         end loop;
         assert stopped
            report "Pan left did not reach the left edge"
            severity error;

         -- The update after the last change checks its picture
         do_update("00000");
         assert not changed severity error;
         check_memory("last picture");

         assert pictures = 1 + changes
            report "Pictures: " & integer'image(pictures) & ", expected " &
                   integer'image(1 + changes) & " (one after reset, and one for each change of the view)"
            severity error;
         assert writes = pictures * C_WORDS
            report "Words written: " & integer'image(writes) & ", expected " &
                   integer'image(pictures * C_WORDS)
            severity error;
         assert fps_count = pictures
            report "The frame rate was updated " & integer'image(fps_count) &
                   " times, expected once for each of the " & integer'image(pictures) & " pictures"
            severity error;

         report "redraw_tb: finished, " & integer'image(pictures) & " pictures for " &
                integer'image(changes) & " changes of the view, the longest took " &
                integer'image(max_time) & " clock cycles";
         std.env.finish;
      end process p_test;

   end block b_test;

end architecture simulation;
