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
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      wr_szcv_i  : in  std_logic_vector(3 downto 0);
      alu_s_i    : in  std_logic;
      alu_z_i    : in  std_logic;
      alu_c_i    : in  std_logic;
      alu_v_i    : in  std_logic;
      wr_b_i     : in  std_logic_vector(1 downto 0);
      wr_c_i     : in  std_logic_vector(1 downto 0);
      wr_i_i     : in  std_logic_vector(1 downto 0);
      wr_d_i     : in  std_logic_vector(1 downto 0);

      wr_sr_i    : in  std_logic_vector(1 downto 0);
      data_i     : in  std_logic_vector(7 downto 0);
      reg_i      : in  std_logic_vector(7 downto 0);

      sr_o       : out std_logic_vector(7 downto 0)
   );
end sr;

architecture Structural of sr is

   signal sr_r : std_logic_vector(7 downto 0);

begin


   -- Status register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_szcv_i(3) = '1' then
            sr_r(7) <= alu_s_i;
         end if;

         if wr_szcv_i(2) = '1' then
            sr_r(1) <= alu_z_i;
         end if;

         if wr_szcv_i(1) = '1' then
            sr_r(0) <= alu_c_i;
         end if;

         if wr_szcv_i(0) = '1' then
            sr_r(6) <= alu_v_i;
         end if;

         if wr_b_i(1) = '1' then
            sr_r(4) <= wr_b_i(0);
         end if;

         if wr_c_i(1) = '1' then
            sr_r(0) <= wr_c_i(0);
         end if;

         if wr_i_i(1) = '1' then
            sr_r(2) <= wr_i_i(0);
         end if;

         if wr_d_i(1) = '1' then
            sr_r(3) <= wr_d_i(0);
         end if;

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

