--------------------------------------
-- The Register File
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity regs is
   port (
           clk_i       : in  std_logic;
           rst_i       : in  std_logic;
           reg_nr_wr_i : in  std_logic_vector( 1 downto 0);
           reg_nr_rd_i : in  std_logic_vector( 1 downto 0);
           data_o      : out std_logic_vector( 7 downto 0);
           wren_i      : in  std_logic;
           data_i      : in  std_logic_vector( 7 downto 0);
           debug_o     : out std_logic_vector(23 downto 0)
   );
end regs;

architecture Structural of regs is

   signal reg_a : std_logic_vector(7 downto 0) := (others => '0');
   signal reg_x : std_logic_vector(7 downto 0) := (others => '0');
   signal reg_y : std_logic_vector(7 downto 0) := (others => '0');

begin

   debug_o( 7 downto  0) <= reg_a;
   debug_o(15 downto  8) <= reg_x;
   debug_o(23 downto 16) <= reg_y;

   data_o <= reg_a when reg_nr_rd_i = "00" else
             reg_x when reg_nr_rd_i = "01" else
             reg_y when reg_nr_rd_i = "10" else
             X"00"; -- when reg_nr_i = "11";

   p_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wren_i = '1' then
            case reg_nr_wr_i is
               when "00" => reg_a <= data_i;
               when "01" => reg_x <= data_i;
               when "10" => reg_y <= data_i;
               when others =>
            end case;
         end if;

         if rst_i = '1' then
            reg_a <= X"00";
            reg_x <= X"00";
            reg_y <= X"00";
         end if;
      end if;
   end process p_reg;

end architecture Structural;

