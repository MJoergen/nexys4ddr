-----------------------------------------------------------------------------
-- Description:  This generates sprites as an overlay.
--               Only 4 sprites are supported to keep resource requirements at
--               a minimum.
--
-- Memory map :
-- Each sprite has associated 0x10 bytes of data
--              0x0000 : bits 7-0 : Sprite 0 X position
--              0x0001 : bits   0 : Sprite 0 X position MSB
--              0x0002 : bits 7-0 : Sprite 0 Y position
--              0x0003 : bits 7-0 : Sprite 0 color (RRRGGGBB)
--              0x0004 : bit    0 : Sprite 0 enabled
--
--              0x0010 : bits 7-0 : Sprite 1 X position
--              0x0011 : bits   0 : Sprite 1 X position MSB
--              0x0012 : bits 7-0 : Sprite 1 Y position
--              0x0013 : bits 7-0 : Sprite 1 color (RRRGGGBB)
--              0x0014 : bit    0 : Sprite 1 enabled
--
--              0x0020 : bits 7-0 : Sprite 2 X position
--              0x0021 : bits   0 : Sprite 2 X position MSB
--              0x0022 : bits 7-0 : Sprite 2 Y position
--              0x0023 : bits 7-0 : Sprite 2 color (RRRGGGBB)
--              0x0024 : bit    0 : Sprite 2 enabled
--
--              0x0030 : bits 7-0 : Sprite 3 X position
--              0x0031 : bits   0 : Sprite 3 X position MSB
--              0x0032 : bits 7-0 : Sprite 3 Y position
--              0x0033 : bits 7-0 : Sprite 3 color (RRRGGGBB)
--              0x0034 : bit    0 : Sprite 3 enabled
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity conf_stat is
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      addr_i   : in  std_logic_vector(7 downto 0);
      --
      wren_i   : in  std_logic;
      data_i   : in  std_logic_vector(7 downto 0);
      --
      rden_i   : in  std_logic;
      data_o   : out std_logic_vector(7 downto 0);
      --
      config_o : out std_logic_vector(26*4-1 downto 0);
      --
      sync_i   : in  std_logic;
      irq_o    : out std_logic
   );
end conf_stat;

architecture Behavioral of conf_stat is

   -- This contains configuration data (26 bits) for each sprite
   -- Bits  8- 0 : X-position
   -- Bits 16- 9 : Y-position
   -- Bits 24-17 : Colour
   -- Bit     25 : Enable
   signal config : std_logic_vector(26*4-1 downto 0);

   -- Latched interrupt
   signal irq_latch : std_logic;

begin

   p_config : process (clk_i)
      variable sprite_num : integer range 0 to 3;
      variable offset     : integer range 0 to 7;
   begin
      if rising_edge(clk_i) then
         sprite_num := conv_integer(addr_i(5 downto 4));

         if wren_i = '1' then
            offset := conv_integer(addr_i(2 downto 0));

            case offset is
               when 0 =>
                  config(sprite_num*26 +  7 downto sprite_num*26 +  0) <= data_i;
               when 1 =>
                  config(sprite_num*26 +  8 downto sprite_num*26 +  8) <= data_i(0 downto 0);
               when 2 =>
                  config(sprite_num*26 + 16 downto sprite_num*26 +  9) <= data_i;
               when 3 =>
                  config(sprite_num*26 + 24 downto sprite_num*26 + 17) <= data_i;
               when 4 =>
                  config(sprite_num*26 + 25 downto sprite_num*26 + 25) <= data_i(0 downto 0);
               when others => null;
            end case;
         end if;

         if rst_i = '1' then
            config <= (others => '0');
         end if;

      end if;
   end process p_config;


   --------------
   -- Status read
   --------------

   p_status : process (clk_i)
   begin
      if falling_edge(clk_i) then
         
         if addr_i = "00000000" and rden_i = '1' then
            data_o <= "0000000" & irq_latch;
            irq_latch <= '0';
         end if;

         if sync_i = '1' then
            irq_latch <= '1';
         end if;

         if rst_i = '1' then
            irq_latch <= '0';
         end if;

      end if;
   end process p_status;


   ----------------------------------------
   -- Drive output signals
   ----------------------------------------

   config_o <= config;
   irq_o    <= irq_latch;


end Behavioral;

