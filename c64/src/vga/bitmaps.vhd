-----------------------------------------------------------------------------
-- Description:  This infers a BRAM to contain 16x16 bitmaps for 4 sprites.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;

entity bitmaps is
   port (
      vga_clk_i   : in  std_logic;
      vga_rst_i   : in  std_logic;

      cpu_clk_i   : in  std_logic;
      cpu_rst_i   : in  std_logic;

      -- Read port @ vga_clk_i
      vga_addr_i  : in  std_logic_vector( 5 downto 0);   -- 2 bits for sprite #, and 4 bits for row.
      vga_data_o  : out std_logic_vector(15 downto 0);
      vga_rden_i  : in  std_logic;

      -- Write port @ cpu_clk_i
      cpu_addr_i  : in  std_logic_vector( 6 downto 0);   -- 2 bits for sprite #, 4 bits for row, and 1 bit for left/right side.
      cpu_data_i  : in  std_logic_vector( 7 downto 0);
      cpu_wren_i  : in  std_logic
   );
end bitmaps;

architecture Behavioral of bitmaps is

   function reverse(arg : std_logic_vector) return std_logic_vector is
      variable res : std_logic_vector(arg'length-1 downto 0);
   begin
      for i in 0 to arg'length-1 loop
         res(i) := arg(arg'length-1-i);
      end loop;
      return res;
   end function reverse;

   -- Bitmaps are stored in BRAM, with 2 address bits to select sprite, and 4 address bits
   -- to select row in sprite (0 - 15).
   type t_bitmaps is array (0 to 63) of std_logic_vector(15 downto 0);

   signal bitmaps : t_bitmaps := (others => (others => '0'));  -- Bitmap data

begin

   -- Read port. This has to be registered in order to make it into a Block RAM.
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_data_o <= bitmaps(conv_integer(vga_addr_i));
      end if;
   end process;


   -- Write port
   process (cpu_clk_i)
      variable index_v : integer range 0 to 63;
   begin
      if rising_edge(cpu_clk_i) then
         index_v := conv_integer(cpu_addr_i(6 downto 1));
         case cpu_addr_i(0) is
            when '0' => bitmaps(index_v)( 7 downto 0) <= cpu_data_i;
            when '1' => bitmaps(index_v)(15 downto 8) <= cpu_data_i;
            when others => null;
         end case;
      end if;
   end process;

end Behavioral;

