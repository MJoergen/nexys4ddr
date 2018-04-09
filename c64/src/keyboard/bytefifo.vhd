--------------------------------------
-- This emulates a simple FIFO with 8-bit entries.
-- It has no overflow handling what-so-ever!
-- It responds to underflow by returning all zeros.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity bytefifo is
   generic (
      SIZE : integer
   );
   port (
      -- Clock
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;

      wren_i : in  std_logic;
      val_i  : in  std_logic_vector(7 downto 0);

      rden_i : in  std_logic;
      val_o  : out std_logic_vector(7 downto 0);

      debug_o : out std_logic_vector(69 downto 0)
   );
end bytefifo;

architecture Structural of bytefifo is

   signal fifo_r  : std_logic_vector(8*SIZE-1 downto 0);
   signal rdptr_r : integer range 0 to SIZE-1 := 0;
   signal wrptr_r : integer range 0 to SIZE-1 := 0;

begin

   debug_o(69 downto 67) <= conv_std_logic_vector(wrptr_r, 3);
   debug_o(66 downto 64) <= conv_std_logic_vector(rdptr_r, 3);
   debug_o(63 downto 0) <= fifo_r(63 downto 0);

   p_rdptr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Only advance read pointer if fifo is not empty.
         if rden_i = '1' and rdptr_r /= wrptr_r then
            if rdptr_r = SIZE-1 then
               rdptr_r <= 0;
            else
               rdptr_r <= rdptr_r + 1;
            end if;
         end if;

         if rst_i = '1' then
            rdptr_r <= 0;
         end if;
      end if;
   end process p_rdptr;

   val_o <= fifo_r(rdptr_r*8 + 7 downto rdptr_r*8) when rdptr_r /= wrptr_r else
            (others => '0');


--   p_val : process (clk_i)
--   begin
--      if rising_edge(clk_i) then
--         val_o <= fifo_r(rdptr_r*8 + 7 downto rdptr_r*8);
--
--            -- Return all zeros, if fifo is empty.
--         if rdptr_r = wrptr_r then
--            val_o <= (others => '0');
--         end if;
--      end if;
--   end process p_val;

   p_fifo : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            fifo_r(wrptr_r*8 + 7 downto wrptr_r*8) <= val_i;
         end if;

         if rst_i = '1' then
            fifo_r <= (others => '0');
         end if;
      end if;
   end process p_fifo;

   p_wrptr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            if wrptr_r = SIZE-1 then
               wrptr_r <= 0;
            else
               wrptr_r <= wrptr_r + 1;
            end if;
         end if;

         if rst_i = '1' then
            wrptr_r <= 0;
         end if;
      end if;
   end process p_wrptr;

end Structural;

