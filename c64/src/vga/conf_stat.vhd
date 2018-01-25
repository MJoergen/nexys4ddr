-----------------------------------------------------------------------------
-- Description:  This generates sprites as an overlay.
--               Only 4 sprites are supported to keep resource requirements at
--               a minimum.
--
-- Memory map : 0x8600 - 0x87FF
-- Each sprite has associated 0x10 bytes of data
--              0x8600 : bits 7-0 : Sprite 0 X position
--              0x8601 : bits   0 : Sprite 0 X position MSB
--              0x8602 : bits 7-0 : Sprite 0 Y position
--              0x8603 : bits 7-0 : Sprite 0 color (RRRGGGBB)
--              0x8604 : bit    0 : Sprite 0 enabled
--
--              0x8610 : bits 7-0 : Sprite 1 X position
--              0x8611 : bits   0 : Sprite 1 X position MSB
--              0x8612 : bits 7-0 : Sprite 1 Y position
--              0x8613 : bits 7-0 : Sprite 1 color (RRRGGGBB)
--              0x8614 : bit    0 : Sprite 1 enabled
--
--              0x8620 : bits 7-0 : Sprite 2 X position
--              0x8621 : bits   0 : Sprite 2 X position MSB
--              0x8622 : bits 7-0 : Sprite 2 Y position
--              0x8623 : bits 7-0 : Sprite 2 color (RRRGGGBB)
--              0x8624 : bit    0 : Sprite 2 enabled
--
--              0x8630 : bits 7-0 : Sprite 3 X position
--              0x8631 : bits   0 : Sprite 3 X position MSB
--              0x8632 : bits 7-0 : Sprite 3 Y position
--              0x8633 : bits 7-0 : Sprite 3 color (RRRGGGBB)
--              0x8634 : bit    0 : Sprite 3 enabled
--
--              0x8640 :            IRQ status (bit 0 : Y-line interrupt)
--              0x8641 :            Y-line
--              0x8650 :            Char foreground color
--              0x8651 :            Char background color
--
-- This whole block is implemented as 0x0080 bytes of LUT RAM.
-- All decoding is done by the user of this block.
-- This simplifies the code, but wastes a lot of memory cells.
-- Bits 8 and 7 of the address input is ignored.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity conf_stat is
   port (
      clk_i    : in  std_logic;     -- @ CPU clock domain
      rst_i    : in  std_logic;
      addr_i   : in  std_logic_vector(8 downto 0);
      --
      wren_i   : in  std_logic;
      data_i   : in  std_logic_vector(7 downto 0);
      --
      rden_i   : in  std_logic;
      data_o   : out std_logic_vector(7 downto 0);
      --
      config_o : out std_logic_vector(128*8-1 downto 0);
      --
      sync_i   : in  std_logic;
      irq_o    : out std_logic
   );
end conf_stat;

architecture Behavioral of conf_stat is

   signal config : std_logic_vector(128*8-1 downto 0);

   -- Latched interrupt
   signal irq_latch : std_logic;

begin

   ------------------
   -- Write to config
   ------------------

   p_config : process (clk_i)
      variable index_v : integer range 0 to 127;
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            index_v := conv_integer(addr_i(6 downto 0));
            config(8*index_v + 7 downto 8*index_v) <= data_i;
         end if;

         if rst_i = '1' then
            config <= (others => '0');
            config(8*80+7 downto 8*80) <= X"44";  -- Char foreground color
            config(8*81+7 downto 8*81) <= X"CC";  -- Char background color
         end if;

      end if;
   end process p_config;


   -------------------
   -- Read from config
   -------------------

   p_read : process (clk_i)
      variable index_v : integer range 0 to 127;
   begin
      if falling_edge(clk_i) then
         if rden_i = '1' then
            index_v := conv_integer(addr_i(6 downto 0));
            data_o <= config(8*index_v + 7 downto 8*index_v);
         end if;
      end if;
   end process p_read;


   ------------------------------------
   -- Control the IRQ signal to the CPU
   ------------------------------------

   p_status : process (clk_i)
   begin
      if falling_edge(clk_i) then
         
         -- Special processing when reading from 0x8640
         if addr_i = B"0_0100_0000" and rden_i = '1' then
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

