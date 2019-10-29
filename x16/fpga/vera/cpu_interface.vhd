library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This block translates between the CPU memory map and the internal memory map.
-- So far, this block only supports CPU write access.
-- TBD: Add CPU read support.

entity cpu_interface is
   port (
      clk_i          : in  std_logic;
      cpu_wr_addr_i  : in  std_logic_vector( 2 downto 0);
      cpu_wr_en_i    : in  std_logic;
      cpu_wr_data_i  : in  std_logic_vector( 7 downto 0);
      vera_wr_addr_o : out std_logic_vector(19 downto 0);
      vera_wr_en_o   : out std_logic;
      vera_wr_data_o : out std_logic_vector( 7 downto 0)
   );
end cpu_interface;

architecture structural of cpu_interface is

   signal address0_r : std_logic_vector(23 downto 0); -- Port 0
   signal address1_r : std_logic_vector(23 downto 0); -- Port 1

   signal addr_sel_r : std_logic := '0';  -- Default port 0

   -- Convert the 4-bit increment setting to a 20-bit increment value.
   function get_increment(arg : std_logic_vector) return std_logic_vector is
      variable idx : integer range 0 to 15;
      variable res : std_logic_vector(19 downto 0) := (others => '0');
   begin
      idx := to_integer(arg);
      if idx > 0 then
         res(idx-1) := '1';
      end if;
      return res;
   end function get_increment;

begin

   -- Write process
   p_write : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vera_wr_addr_o <= (others => '0');
         vera_wr_en_o   <= '0';
         vera_wr_data_o <= (others => '0');

         if cpu_wr_en_i = '1' then
            case cpu_wr_addr_i is
               -- VERA_ADDR_LO
               when "000" => if addr_sel_r = '0' then
                                address0_r( 7 downto  0) <= cpu_wr_data_i;
                             else
                                address1_r( 7 downto  0) <= cpu_wr_data_i;
                             end if;

               -- VERA_ADDR_MID
               when "001" => if addr_sel_r = '0' then
                                address0_r(15 downto  8) <= cpu_wr_data_i;
                             else
                                address1_r(15 downto  8) <= cpu_wr_data_i;
                             end if;

               -- VERA_ADDR_HI
               when "010" => if addr_sel_r = '0' then
                                address0_r(23 downto 16) <= cpu_wr_data_i;
                             else
                                address1_r(23 downto 16) <= cpu_wr_data_i;
                             end if;

               -- VERA_ADDR_DATA0
               when "011" => vera_wr_addr_o <= address0_r(19 downto 0);
                             vera_wr_en_o   <= '1';
                             vera_wr_data_o <= cpu_wr_data_i;
                             address0_r(19 downto 0) <= address0_r(19 downto  0) +
                                          get_increment(address0_r(23 downto 20));

               -- VERA_ADDR_DATA1
               when "100" => vera_wr_addr_o <= address1_r(19 downto 0);
                             vera_wr_en_o   <= '1';
                             vera_wr_data_o <= cpu_wr_data_i;
                             address1_r(19 downto 0) <= address1_r(19 downto  0) +
                                          get_increment(address1_r(23 downto 20));

               -- VERA_ADDR_CTRL
               when "101" => addr_sel_r <= cpu_wr_data_i(0);
                             -- TBD: Missing Reset.
               
               -- VERA_IEN
               when "110" => null; -- TBD

               -- VERA_ISR
               when "111" => null; -- TBD

               when others => null;
            end case;
         end if;
      end if;
   end process p_write;

end architecture structural;

