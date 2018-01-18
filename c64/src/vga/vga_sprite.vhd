-----------------------------------------------------------------------------
-- Description:  This generates sprites as an overlay.
--               Only 4 sprites are supported to keep resource requirements at
--               a minimum.
--
-- Memory map :
-- Each sprite has associated 0x40 bytes of data
--              0x0000 - 0x001F : Sprite 0 bitmap area
--              0x0020          : bits 7-0 : Sprite 0 X position
--              0x0021          : bits   0 : Sprite 0 X position MSB
--              0x0022          : bits 7-0 : Sprite 0 Y position
--              0x0023          : bits 7-0 : Sprite 0 color (RRRGGGBB)
--              0x0024          : bit    0 : Sprite 0 enabled
--
--              0x0040 - 0x005F : Sprite 1 bitmap area
--              0x0060          : bits 7-0 : Sprite 1 X position
--              0x0061          : bits   0 : Sprite 1 X position MSB
--              0x0062          : bits 7-0 : Sprite 1 Y position
--              0x0063          : bits 7-0 : Sprite 1 color (RRRGGGBB)
--              0x0064          : bit    0 : Sprite 1 enabled
--
--              0x0080 - 0x009F : Sprite 2 bitmap area
--              0x00A0          : bits 7-0 : Sprite 2 X position
--              0x00A1          : bits   0 : Sprite 2 X position MSB
--              0x00A2          : bits 7-0 : Sprite 2 Y position
--              0x00A3          : bits 7-0 : Sprite 2 color (RRRGGGBB)
--              0x00A4          : bit    0 : Sprite 2 enabled
--
--              0x00C0 - 0x00DF : Sprite 3 bitmap area
--              0x00E0          : bits 7-0 : Sprite 3 X position
--              0x00E1          : bits   0 : Sprite 3 X position MSB
--              0x00E2          : bits 7-0 : Sprite 3 Y position
--              0x00E3          : bits 7-0 : Sprite 3 color (RRRGGGBB)
--              0x00E4          : bit    0 : Sprite 3 enabled
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity vga_sprite is
   generic (
      G_DO_RD_REG  : boolean;     -- Register on read port?
      G_RD_CLK_RIS : boolean      -- Rising clock on read port?
   );
   port (
      vga_clk_i   : in  std_logic;
      vga_rst_i   : in  std_logic;

      cpu_clk_i   : in  std_logic;
      cpu_rst_i   : in  std_logic;

      -- Inputs @ vga_clk_i
      hcount_i    : in  std_logic_vector(10 downto 0);
      vcount_i    : in  std_logic_vector(10 downto 0);
      hs_i        : in  std_logic;
      vs_i        : in  std_logic;
      col_i       : in  std_logic_vector(11 downto 0);

      -- Outputs @ vga_clk_i
      hcount_o    : out std_logic_vector(10 downto 0);
      vcount_o    : out std_logic_vector(10 downto 0);
      hs_o        : out std_logic;
      vs_o        : out std_logic;
      col_o       : out std_logic_vector(11 downto 0);

      -- Configuration and status @ cpu_clk_i
      cpu_addr_i  : in  std_logic_vector(7 downto 0);
      cpu_wren_i  : in  std_logic;
      cpu_data_i  : in  std_logic_vector(7 downto 0);
      cpu_data_o  : out std_logic_vector(7 downto 0);
      cpu_irq_o   : out std_logic;

      debug_o     : out std_logic_vector(2 downto 0)
   );
end vga_sprite;

architecture Behavioral of vga_sprite is

   function reverse(arg : std_logic_vector) return std_logic_vector is
      variable res : std_logic_vector(arg'length-1 downto 0);
   begin
      for i in 0 to arg'length-1 loop
         res(i) := arg(arg'length-1-i);
      end loop;
      return res;
   end function reverse;

   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      return arg(7 downto 5) & "0" & arg(4 downto 2) & "0" & arg(1 downto 0) & "00";
   end function col8to12;

   ----------------------------------------------------------------------

   -- Pipeline
   type t_stage is record
      hcount          : std_logic_vector(10 downto 0);     -- Valid in stage 0
      vcount          : std_logic_vector(10 downto 0);     -- Valid in stage 0
      hs              : std_logic;                         -- Valid in stage 0
      vs              : std_logic;                         -- Valid in stage 0
      col             : std_logic_vector(11 downto 0);     -- Valid in stage 0
      row_index       : std_logic_vector(4*4-1 downto 0);  -- Valid in stage 1 (0 - 15) for each sprite
      row_index_valid : std_logic_vector(3 downto 0);      -- Valid in stage 1
      col_index       : std_logic_vector(4*4-1 downto 0);  -- Valid in stage 1 (0 - 15) for each sprite
      col_index_valid : std_logic_vector(3 downto 0);      -- Valid in stage 1
      pix             : std_logic_vector(3 downto 0);      -- Valid in stage 6
      collision       : std_logic_vector(3 downto 0);      -- Valid in stage 6
   end record t_stage;

   constant STAGE_DEFAULT : t_stage := (
      hcount          => (others => '0'),
      vcount          => (others => '0'),
      hs              => '0',
      vs              => '0',
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
   signal stage4 : t_stage := STAGE_DEFAULT;
   signal stage5 : t_stage := STAGE_DEFAULT;
   signal stage6 : t_stage := STAGE_DEFAULT;
   signal stage7 : t_stage := STAGE_DEFAULT;

   ----------------------------------------------------------------------

   -- This contains configuration data for each sprite
   type t_config is record
      posx        : std_logic_vector(8 downto 0);
      posy        : std_logic_vector(7 downto 0);
      color       : std_logic_vector(7 downto 0);
      enable      : std_logic;
   end record t_config;

   type t_config_vector is array (natural range <>) of t_config;

   signal config  : t_config_vector(3 downto 0);   -- Configuration data

   ----------------------------------------------------------------------

   -- Signals connected to the sprite bitmap BRAM
   signal vga_addr   : std_logic_vector( 5 downto 0);   -- 2 bits for sprite #, and 4 bits for row.
   signal vga_data   : std_logic_vector(15 downto 0);
   signal vga_rden   : std_logic;

   signal cpu_addr   : std_logic_vector( 6 downto 0);   -- 2 bits for sprite #, 4 bits for row, and 1 bit for left/right.
   signal cpu_data   : std_logic_vector( 7 downto 0);
   signal cpu_wren   : std_logic;

   -- State machine to read sprite bitmaps from BRAM
   type t_fsm is (IDLE_ST, READING_ST);
   signal fsm_state   : t_fsm := IDLE_ST;
   signal sprite      : integer range 0 to 3; -- Current sprite number being read from bitmap RAM
   signal fsm_rden    : std_logic_vector(3 downto 0);
   signal fsm_addr    : std_logic_vector(4*4-1 downto 0);
   signal vga_rden_d  : std_logic;
   signal vga_addr_d  : std_logic_vector(5 downto 0);
   signal stage5_rows : std_logic_vector(16*4-1 downto 0);

   ----------------------------------------------------------------------

   -- Latched collusion status
   signal vga_coll_latch : std_logic_vector(3 downto 0) := (others => '0');

   -- Latched interrupt
   signal vga_irq_latch : std_logic;

   -- Clear signals from the CPU
   signal coll_clear_cpu : std_logic;
   signal irq_clear_cpu  : std_logic;

   -- Clock domain crossing
   signal coll_clear_vga : std_logic;
   signal irq_clear_vga  : std_logic;

begin

   -----------------
   -- Internal check
   -----------------

   assert G_DO_RD_REG  = true report "Wrong value for G_DO_RD_REG" severity failure;
   assert G_RD_CLK_RIS = false report "Wrong value for G_RD_CLK_RIS" severity failure;


   ------------------------------------------------------------------------
   -- Control reading sprite bitmaps from the BRAM.
   -- Reading starts when hcount_i = 0 and takes one clock cycle pr sprite.
   -- With 4 sprites, the bitmap data is ready at stage 5.
   ------------------------------------------------------------------------

   gen_addr : for i in 0 to 3 generate
      fsm_addr(4*(i+1)-1 downto 4*i) <= vcount_i(4 downto 1) - config(i).posy(3 downto 0);
   end generate gen_addr;

   p_fsm : process (vga_clk_i)
      variable pix_y_v : std_logic_vector( 9 downto 0);
      variable fsm_rden_v : std_logic_vector(3 downto 0);
   begin
      if rising_edge(vga_clk_i) then
         vga_rden <= '0';

         case fsm_state is
            when IDLE_ST =>
               if hcount_i = 0 then
                  -- Generate read signals for all sprites at once.
                  for i in 0 to 3 loop
                     pix_y_v := stage0.vcount(10 downto 1) - ("00" & config(i).posy);

                     fsm_rden_v(i) := '0';
                     if pix_y_v <= 15 then
                        fsm_rden_v(i) := config(i).enable;
                     end if;
                  end loop;

                  vga_rden <= fsm_rden_v(0);
                  vga_addr <= "00" & fsm_addr(3 downto 0);

                  fsm_rden <= fsm_rden_v;
                  fsm_state <= READING_ST;

                  sprite <= 1; -- Prepare reading sprite 0 bitmap
               end if;

            when READING_ST =>
               vga_rden <= fsm_rden(sprite);
               vga_addr <= conv_std_logic_vector(sprite, 2) & fsm_addr(4*sprite + 3 downto 4*sprite);

               if sprite /= 3 then
                  sprite <= sprite + 1;
               else
                  fsm_state <= IDLE_ST;
               end if;

         end case;
      end if;
   end process p_fsm;


   ---------------------------------
   -- Instantiate sprite bitmap BRAM
   ---------------------------------

   inst_bitmaps : entity work.bitmaps
   port map (
      vga_clk_i   => vga_clk_i,
      vga_rst_i   => vga_rst_i,

      cpu_clk_i   => cpu_clk_i,
      cpu_rst_i   => cpu_rst_i,

      -- Read port @ vga_clk_i
      vga_addr_i  => vga_addr,
      vga_data_o  => vga_data,

      -- Write port @ cpu_clk_i
      cpu_wren_i  => cpu_wren,
      cpu_addr_i  => cpu_addr,
      cpu_data_i  => cpu_data
   );


   -------------------------
   -- Store output from BRAM
   -------------------------

   -- Store for use next clock cycle
   p_delay : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_rden_d <= vga_rden;
         vga_addr_d <= vga_addr;
      end if;
   end process p_delay;

   gen_bitmap_row : for i in 0 to 3 generate
      p_bitmap_row : process (vga_clk_i)
      begin
         if rising_edge(vga_clk_i) then
            if vga_rden_d = '1' and conv_integer(vga_addr_d(5 downto 4)) = i then
               stage5_rows(i*16 + 15 downto i*16) <= vga_data;
            end if;
            if vga_rst_i = '1' then
               stage5_rows(i*16 + 15 downto i*16) <= (others => '0');
            end if;
         end if;
      end process p_bitmap_row;
   end generate gen_bitmap_row;
   



   ----------------------------
   -- Stage 0
   ----------------------------

   stage0.hcount <= hcount_i;
   stage0.vcount <= vcount_i;
   stage0.hs     <= hs_i;
   stage0.vs     <= vs_i;
   stage0.col    <= col_i;


   ----------------------------------------
   -- Stage 1 : Calculate horizontal
   ----------------------------------------

   p_stage1 : process (vga_clk_i)
      variable pix_x_v : std_logic_vector( 9 downto 0);
      variable pix_y_v : std_logic_vector( 9 downto 0);
   begin
      if rising_edge(vga_clk_i) then
         stage1 <= stage0;

         stage1.col_index_valid <= (others => '0');
         stage1.row_index_valid <= (others => '0');

         for i in 0 to 3 loop
            pix_x_v := stage0.hcount(10 downto 1) - ("0" & config(i).posx);
            stage1.col_index(4*(i+1)-1 downto 4*i) <= pix_x_v(3 downto 0);
            if pix_x_v <= 15 then
               stage1.col_index_valid(i) <= config(i).enable;
            end if;

            pix_y_v := stage0.vcount(10 downto 1) - ("00" & config(i).posy);
            stage1.row_index(4*(i+1)-1 downto 4*i) <= pix_y_v(3 downto 0);
            if pix_y_v <= 15 then
               stage1.row_index_valid(i) <= config(i).enable;
            end if;
         end loop;

      end if;
   end process p_stage1;



   --------------------------------------------
   -- Stage 2, 3, 4, and 5: Wait for BRAM reads
   --------------------------------------------

   p_stage2345 : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         stage2 <= stage1;
         stage3 <= stage2;
         stage4 <= stage3;
         stage5 <= stage4;
      end if;
   end process p_stage2345;


   ----------------------------------------
   -- Stage 6
   ----------------------------------------

   p_stage6 : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         stage6 <= stage5;

         stage6.pix <= (others => '0');
         for i in 3 downto 0 loop
            if stage5.row_index_valid(i) = '1' and stage5.col_index_valid(i) = '1' then
               stage6.pix(i) <= stage5_rows(i*16 + conv_integer(stage5.col_index(i*4 + 3 downto i*4)));
            end if;
         end loop;

      end if;
   end process p_stage6;


   ----------------------------------------
   -- Stage 7
   ----------------------------------------

   p_stage7 : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         stage7 <= stage6;

         for i in 3 downto 0 loop
            if stage6.pix(i) = '1' then
               stage7.col <= col8to12(config(i).color);
            end if;
         end loop;

         -- More than 1 bit set in stage6.pix indicates collision between two
         -- or more sprites.
         stage7.collision <= (others => '0');
         if (stage6.pix and (stage6.pix - 1)) /= 0 then
            stage7.collision <= stage6.pix;
         end if;

      end if;
   end process p_stage7;


   ----------------------
   -- Latch output to CPU
   ----------------------

   p_latch_vga : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then

         -- Latch collision values.
         for i in 0 to 3 loop
            if stage7.collision(i) = '1' then
               vga_coll_latch(i) <= '1';
            end if;
         end loop;

         -- Latch interrupt at start of specific vertical line.
         if stage7.hcount = 0 and stage7.vcount = 1 then -- 480 then
            vga_irq_latch <= '1';
         end if;

         -- Clear latched values when requested by CPU
         if coll_clear_vga = '1' then
            vga_coll_latch <= (others => '0');
         end if;

         if irq_clear_vga = '1' then
            vga_irq_latch <= '0';
         end if;

         if vga_rst_i = '1' then
            vga_coll_latch <= (others => '0');
            vga_irq_latch  <= '0';
         end if;

      end if;
   end process p_latch_vga;


   ------------------------------------------
   -- Clock crossing : cpu_clk_i -> vga_clk_i
   ------------------------------------------

   -- Note: We assume that the VGA clock is faster than the CPU clock
   -- Therefore, the CPU pulse is long enough to be sampled.
   p_cc : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         irq_clear_vga  <= irq_clear_cpu;
         coll_clear_vga <= coll_clear_cpu;
      end if;
   end process p_cc;


   ----------------------------------------
   -- Configuration write @ cpu_clk_i
   ----------------------------------------

   p_sprites : process (cpu_clk_i)
      variable sprite_num : integer range 0 to 3;
      variable offset : integer range 0 to 7;
   begin
      if rising_edge(cpu_clk_i) then
         cpu_wren <= '0';
         sprite_num := conv_integer(cpu_addr_i(7 downto 6));

         if cpu_wren_i = '1' then
            if cpu_addr_i(5) = '0' then
               cpu_wren <= '1';
               cpu_addr <= cpu_addr_i(7 downto 6) & cpu_addr_i(4 downto 0);
               cpu_data <= reverse(cpu_data_i);
            else -- addr_i(4) = '1' 
               offset := conv_integer(cpu_addr_i(2 downto 0));

               case offset is
                  when 0 => config(sprite_num).posx(7 downto 0)   <= cpu_data_i;
                  when 1 => config(sprite_num).posx(8)            <= cpu_data_i(0); 
                  when 2 => config(sprite_num).posy               <= cpu_data_i;
                  when 3 => config(sprite_num).color              <= cpu_data_i;
                  when 4 => config(sprite_num).enable             <= cpu_data_i(0);
                  when others => null;
               end case;
            end if;
         end if;

         if cpu_rst_i = '1' then
            for i in 0 to 3 loop
               config(i).posx   <= (others => '0');
               config(i).posy   <= (others => '0');
               config(i).color  <= (others => '0');
               config(i).enable <= '0';
            end loop;
         end if;
      end if;
   end process p_sprites;


   --------------------------
   -- Status read @ cpu_clk_i
   --------------------------

   p_status : process (cpu_clk_i)
   begin
      if falling_edge(cpu_clk_i) then
         coll_clear_cpu <= '0';
         irq_clear_cpu  <= '0';

         cpu_data_o <= (others => '0');

         if cpu_addr_i = "00000000" then
            cpu_data_o <= "0000" & vga_coll_latch;
            coll_clear_cpu <= '1';
         end if;

         if cpu_addr_i = "00000001" then
            cpu_data_o <= "0000000" & vga_irq_latch;
            irq_clear_cpu <= '1';
         end if;

         if cpu_rst_i = '1' then
            coll_clear_cpu <= '1';
            irq_clear_cpu  <= '1';
         end if;

      end if;
   end process p_status;

   debug_o(0) <= irq_clear_cpu;
   debug_o(1) <= irq_clear_vga;
   debug_o(2) <= vga_irq_latch;


   ----------------------------------------
   -- Drive output signals
   ----------------------------------------

   hcount_o  <= stage7.hcount;
   vcount_o  <= stage7.vcount;
   hs_o      <= stage7.hs;
   vs_o      <= stage7.vs;
   col_o     <= stage7.col;
   cpu_irq_o <= vga_irq_latch;


end Behavioral;

