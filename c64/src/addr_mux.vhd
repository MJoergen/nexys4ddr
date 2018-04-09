library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity addr_mux is
   port (
      lo_addr_i     : in  std_logic_vector(15 downto 0);
      lo_wr_en_i    : in  std_logic;
      lo_wr_data_i  : in  std_logic_vector(7 downto 0);
      lo_wait_i     : in  std_logic;
      hi_addr_i     : in  std_logic_vector(15 downto 0);
      hi_wr_en_i    : in  std_logic;
      hi_wr_data_i  : in  std_logic_vector(7 downto 0);
      hi_wait_i     : in  std_logic;
      res_addr_o    : out std_logic_vector(15 downto 0);
      res_wr_en_o   : out std_logic;
      res_wr_data_o : out std_logic_vector(7 downto 0);
      res_wait_o    : out std_logic
   );
end addr_mux;

architecture Structural of addr_mux is

begin

   process (lo_addr_i, lo_wr_en_i, lo_wr_data_i, lo_wait_i, hi_addr_i, hi_wr_en_i, hi_wr_data_i, hi_wait_i)
   begin
      res_addr_o    <= lo_addr_i;
      res_wr_en_o   <= lo_wr_en_i;
      res_wr_data_o <= lo_wr_data_i;
      res_wait_o    <= lo_wait_i;

      if hi_wr_en_i = '1' then
         res_addr_o    <= hi_addr_i;
         res_wr_en_o   <= hi_wr_en_i;
         res_wr_data_o <= hi_wr_data_i;
         res_wait_o    <= hi_wait_i;
      end if;
   end process;

end Structural;

