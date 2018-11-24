library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a Dual-Port memory
-- Port A supports read and write
-- Port B is read-only

entity dmem is
   generic (
      G_ADDR_BITS : integer;
      G_INIT_VAL  : std_logic_vector(7 downto 0) := X"00"
   );
   port (
      -- Port A
      a_clk_i  : in  std_logic;
      a_addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      a_data_o : out std_logic_vector(7 downto 0);
      a_data_i : in  std_logic_vector(7 downto 0);
      a_wren_i : in  std_logic;

      -- Port B
      b_clk_i  : in  std_logic;
      b_addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      b_data_o : out std_logic_vector(7 downto 0)
   );
end dmem;

architecture structural of dmem is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 2**G_ADDR_BITS-1) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal mem : mem_t := (others => G_INIT_VAL);

begin
  
   -- Port A
   p_port_a : process (a_clk_i)
   begin
      if rising_edge(a_clk_i) then
         if a_wren_i = '1' then
            mem(to_integer(a_addr_i)) <= a_data_i;
         end if;
         a_data_o <= mem(to_integer(a_addr_i));
      end if;
   end process p_port_a;

   -- Port B
   p_port_b : process (b_clk_i)
   begin
      if rising_edge(b_clk_i) then
         b_data_o <= mem(to_integer(b_addr_i));
      end if;
   end process p_port_b;

end structural;

