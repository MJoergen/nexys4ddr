-----------------------------------------------------------------------------
-- Description:  This infers a BRAM to contain 16x16 bitmaps for 4 sprites.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;

entity bitmaps_mem is
   port (
      vga_clk_i   : in  std_logic;

      cpu_clk_i   : in  std_logic;

      -- Read port @ vga_clk_i
      vga_addr_i  : in  std_logic_vector( 5 downto 0);   -- 2 bits for sprite #, and 4 bits for row.
      vga_data_o  : out std_logic_vector(15 downto 0);

      -- Write port @ cpu_clk_i
      cpu_addr_i  : in  std_logic_vector( 6 downto 0);   -- 2 bits for sprite #, 4 bits for row, and 1 bit for left/right side.
      cpu_wren_i  : in  std_logic;
      cpu_data_i  : in  std_logic_vector( 7 downto 0);
      --
      cpu_rden_i  : in  std_logic;
      cpu_data_o  : out std_logic_vector( 7 downto 0)
   );
end bitmaps_mem;

architecture Behavioral of bitmaps_mem is

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

   signal cpu_data : std_logic_vector(7 downto 0);

begin

   -- VGA port. This has to be registered in order to make it into a Block RAM.
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         vga_data_o <= bitmaps(conv_integer(vga_addr_i));
      end if;
   end process;


   -- CPU port
   process (cpu_clk_i)
      variable index_v : integer range 0 to 63;
   begin
      if rising_edge(cpu_clk_i) then
         index_v := conv_integer(cpu_addr_i(6 downto 1));

         if cpu_wren_i = '1' then
            case cpu_addr_i(0) is
               when '0' => bitmaps(index_v)( 7 downto 0) <= reverse(cpu_data_i);
               when '1' => bitmaps(index_v)(15 downto 8) <= reverse(cpu_data_i);
               when others => null;
            end case;
         end if;
      end if;
   end process;

   process (cpu_clk_i)
      variable index_v : integer range 0 to 63;
   begin
      if falling_edge(cpu_clk_i) then
         cpu_data <= (others => '0');
         index_v := conv_integer(cpu_addr_i(6 downto 1));

         if cpu_rden_i = '1' then
            case cpu_addr_i(0) is
               when '0' => cpu_data <= bitmaps(index_v)( 7 downto 0);
               when '1' => cpu_data <= bitmaps(index_v)(15 downto 8);
               when others => null;
            end case;
         end if;
      end if;
   end process;

   cpu_data_o <= reverse(cpu_data);

end Behavioral;

