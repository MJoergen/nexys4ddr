--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sr is
   port (
      -- Clock
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;

      wr_mask_i : in  std_logic_vector(7 downto 0);
      wr_data_i : in  std_logic_vector(7 downto 0);

      wr_sr_i   : in  std_logic_vector(1 downto 0);
      data_i    : in  std_logic_vector(7 downto 0);
      reg_i     : in  std_logic_vector(7 downto 0);

      sr_o      : out std_logic_vector(7 downto 0)
   );
end sr;

architecture Structural of sr is

   signal sr_r : std_logic_vector(7 downto 0);

begin

   -- Status register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         sr_r <= (sr_r and (not wr_mask_i)) or (wr_data_i and wr_mask_i);

         if wr_sr_i(1) = '1' then
            if wr_sr_i(0) = '1' then
               sr_r <= data_i;          -- Used during RTI
            else
               sr_r <= reg_i;    -- Not currently used ????
            end if;
         end if;

         if rst_i = '1' then
            sr_r <= X"04";              -- Interrupts are disabled after reset.
         end if;
      end if;
   end process p_sr;


   -----------------------
   -- Drive output signals
   -----------------------

   sr_o <= sr_r;

end Structural;

