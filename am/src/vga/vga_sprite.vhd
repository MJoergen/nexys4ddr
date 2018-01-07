-----------------------------------------------------------------------------
-- Description:  This generates sprites as an overlay.
--               Configuration information is taken from a RAM.
--               Sprite 0 has the highest priority.
--               The design is inpired by the VIC-II from the C-64,
--               but has been greatly simplified and reduced in
--               functionality.
--               Only 4 sprites are support to keep resource 
--               requirements at a minimum.
--
-- Memory map :
--              0x0000 - 0x003F : Sprite 0 bitmap area
--              0x0040 - 0x007F : Sprite 1 bitmap area
--              0x0080 - 0x00BF : Sprite 2 bitmap area
--              0x00C0 - 0x00FF : Sprite 3 bitmap area
--
--              0x0100          : Sprite 0 X position (bits 7 - 0)
--              0x0101          : bit 0 : Sprite 0 X position bit 8.
--              0x0102          : Sprite 0 Y position
--              0x0103          : Sprite 0 color (RRRGGGBB)
--              0x0104          : bit 0 : Sprite 0 enabled
--              0x0105          : bit 0 : Sprite 0 behind text
--
--              0x0108          : Sprite 1 X position (bits 7 - 0)
--              0x0109          : bit 0 : Sprite 1 X position bit 8.
--              0x010A          : Sprite 1 Y position
--              0x010B          : Sprite 1 color (RRRGGGBB)
--              0x010C          : bit 0 : Sprite 1 enabled
--              0x010D          : bit 0 : Sprite 1 behind text
--
--              0x0110          : Sprite 2 X position (bits 7 - 0)
--              0x0111          : bit 0 : Sprite 2 X position bit 8.
--              0x0112          : Sprite 2 Y position
--              0x0113          : Sprite 2 color (RRRGGGBB)
--              0x0114          : bit 0 : Sprite 2 enabled
--              0x0115          : bit 0 : Sprite 2 behind text
--
--              0x0118          : Sprite 3 X position (bits 7 - 0)
--              0x0119          : bit 0 : Sprite 3 X position bit 8.
--              0x011A          : Sprite 3 Y position
--              0x011B          : Sprite 3 color (RRRGGGBB)
--              0x011C          : bit 0 : Sprite 3 enabled
--              0x011D          : bit 0 : Sprite 3 behind text
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vga_sprite is
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

      -- Configuration @ cpu_clk_i
      addr_i      : in  std_logic_vector(8 downto 0);
      cs_i        : in  std_logic;
      data_o      : out std_logic_vector(7 downto 0);
      wren_i      : in  std_logic;
      data_i      : in  std_logic_vector(7 downto 0)
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

   -- This contains configuration data for each sprite
   type t_sprite is record
      bitmap      : std_logic_vector(21*24-1 downto 0);
      posx        : std_logic_vector(8 downto 0);
      posy        : std_logic_vector(7 downto 0);
      color       : std_logic_vector(7 downto 0);
      enable      : std_logic;
      behind      : std_logic;
   end record t_sprite;

   type t_sprite_vector is array (natural range <>) of t_sprite;

   -- Pipeline
   type t_stage is record
      hcount : std_logic_vector(10 downto 0);    -- Valid in stage 0
      vcount : std_logic_vector(10 downto 0);    -- Valid in stage 0
      hs     : std_logic;                        -- Valid in stage 0
      vs     : std_logic;                        -- Valid in stage 0
      col    : std_logic_vector(11 downto 0);    -- Valid in stage 0
      index  : std_logic_vector(4*9-1 downto 0); -- Valid in stage 1
      show   : std_logic_vector(3 downto 0);     -- Valid in stage 1
      pix    : std_logic_vector(3 downto 0);     -- Valid in stage 2
   end record t_stage;

   constant STAGE_DEFAULT : t_stage := (
      hcount => (others => '0'),
      vcount => (others => '0'),
      hs     => '0',
      vs     => '0',
      col    => (others => '0'),
      index  => (others => '0'),
      show   => (others => '0'),
      pix    => (others => '0')
   );

   signal sprites : t_sprite_vector(3 downto 0);   -- Configuration data

   signal stage0 : t_stage := STAGE_DEFAULT;
   signal stage1 : t_stage := STAGE_DEFAULT;
   signal stage2 : t_stage := STAGE_DEFAULT;
   signal stage3 : t_stage := STAGE_DEFAULT;

begin

   ----------------------------
   -- Stage 0
   ----------------------------

   stage0.hcount <= hcount_i;
   stage0.vcount <= vcount_i;
   stage0.hs     <= hs_i;
   stage0.vs     <= vs_i;
   stage0.col    <= col_i;


   ----------------------------------------
   -- Stage 1 : Calculate index into bitmap
   ----------------------------------------

   p_stage1 : process (vga_clk_i)
      variable v_pix_x : std_logic_vector( 9 downto 0);
      variable v_pix_y : std_logic_vector( 9 downto 0);
      variable v_index : std_logic_vector(19 downto 0);
      constant c24 : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(24, 10));
   begin
      if rising_edge(vga_clk_i) then
         stage1 <= stage0;

         for i in 0 to 3 loop
            stage1.show(i) <= '0';
            v_pix_x := stage0.hcount(10 downto 1) - ("0" & sprites(i).posx);
            v_pix_y := stage0.vcount(10 downto 1) - ("00" & sprites(i).posy);
            if v_pix_x < 24 and v_pix_y < 21 and sprites(i).enable = '1' then
               stage1.show(i) <= '1';

               v_index := v_pix_y*c24 + v_pix_x;
               stage1.index(9*(i+1)-1 downto 9*i) <= v_index(8 downto 0);
            end if;
         end loop;
      end if;
   end process p_stage1;


   ----------------------------------------
   -- Stage 2
   ----------------------------------------

   p_stage2 : process (vga_clk_i)
      variable v_index : integer range 0 to 24*21-1;
   begin
      if rising_edge(vga_clk_i) then
         stage2 <= stage1;

         for i in 0 to 3 loop
            v_index := conv_integer(stage1.index(9*(i+1)-1 downto 9*i));
            stage2.pix(i) <= sprites(i).bitmap(v_index);
         end loop;
      end if;
   end process p_stage2;


   ----------------------------------------
   -- Stage 3
   ----------------------------------------

   p_stage3 : process (vga_clk_i)
      variable v_color : std_logic_vector(7 downto 0) := (others => '0');
      function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
      begin
         return arg(7 downto 5) & "0" & arg(4 downto 2) & "0" & arg(1 downto 0) & "00";
      end function col8to12;
   begin
      if rising_edge(vga_clk_i) then
         stage3 <= stage2;

         -- Sprites behind
         for i in 3 downto 0 loop
            if stage2.show(i) = '1' and stage2.pix(i) = '1' and sprites(i).behind = '1' then
               stage3.col <= col8to12(sprites(i).color);
            end if;
         end loop;

         -- Sprites in front
         for i in 3 downto 0 loop
            if stage2.show(i) = '1' and stage2.pix(i) = '1' and sprites(i).behind = '0' then
               stage3.col <= col8to12(sprites(i).color);
            end if;
         end loop;

      end if;
   end process p_stage3;


   ----------------------------------------
   -- Drive output signals
   ----------------------------------------

   hcount_o <= stage3.hcount;
   vcount_o <= stage3.vcount;
   hs_o     <= stage3.hs;
   vs_o     <= stage3.vs;
   col_o    <= stage3.col;


   ----------------------------------------
   -- Configuration write
   ----------------------------------------

   p_sprites : process (cpu_clk_i)
      variable sprite_num : integer range 0 to 3;
      variable offset : integer range 0 to 63;
   begin
      if rising_edge(cpu_clk_i) then
         if cs_i = '1' and wren_i = '1' then
            if addr_i(8) = '0' then
               sprite_num := conv_integer(addr_i(7 downto 6));
               offset := conv_integer(addr_i(5 downto 0));
               sprites(sprite_num).bitmap(offset*8+7 downto offset*8) <= reverse(data_i);
            else -- addr_i(8) = '1' 
               sprite_num := conv_integer(addr_i(4 downto 3));
               offset := conv_integer(addr_i(2 downto 0));

               case offset is
                  when 0 => sprites(sprite_num).posx(7 downto 0) <= data_i;
                  when 1 => sprites(sprite_num).posx(8)          <= data_i(0);
                  when 2 => sprites(sprite_num).posy             <= data_i;
                  when 3 => sprites(sprite_num).color            <= data_i;
                  when 4 => sprites(sprite_num).enable           <= data_i(0);
                  when 5 => sprites(sprite_num).behind           <= data_i(0);
                  when others => null;
               end case;
            end if;
         end if;

         if cpu_rst_i = '1' then
            for i in 0 to 3 loop
               sprites(i).posx   <= (others => '0');
               sprites(i).posy   <= (others => '0');
               sprites(i).color  <= (others => '0');
               sprites(i).enable <= '0';
               sprites(i).behind <= '0';
               sprites(i).bitmap <= (others => '0');
            end loop;
         end if;
      end if;
   end process p_sprites;


   ----------------------------------------
   -- Configuration read
   ----------------------------------------

   process (addr_i, cs_i, wren_i, sprites)
      variable sprite_num : integer range 0 to 3;
      variable offset : integer range 0 to 63;
   begin
      data_o <= (others => 'Z');
      if cs_i = '1' and wren_i = '0' then
         data_o <= (others => '0');
         if addr_i(8) = '0' then
            sprite_num := conv_integer(addr_i(7 downto 6));
            offset := conv_integer(addr_i(5 downto 0));
            data_o <= reverse(sprites(sprite_num).bitmap(offset*8+7 downto offset*8));
         else -- addr_i(8) = '1' 
            sprite_num := conv_integer(addr_i(4 downto 3));
            offset := conv_integer(addr_i(2 downto 0));

            case offset is
               when 0 => data_o <= sprites(sprite_num).posx(7 downto 0);
               when 1 => data_o <= "0000000" & sprites(sprite_num).posx(8);
               when 2 => data_o <= sprites(sprite_num).posy;
               when 3 => data_o <= sprites(sprite_num).color;
               when 4 => data_o <= "0000000" & sprites(sprite_num).enable;
               when 5 => data_o <= "0000000" & sprites(sprite_num).behind;
               when others => null;
            end case;
         end if;
      end if;
   end process;

end Behavioral;

