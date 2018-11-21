library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity memio is
   generic (
      G_ADDR_BITS : integer;
      G_INIT_VAL  : std_logic_vector(8*32-1 downto 0)
   );
   port (
      clk_i  : in  std_logic;

      -- Port A
      a_addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);
      a_data_o : out std_logic_vector(7 downto 0);
      a_data_i : in  std_logic_vector(7 downto 0);
      a_wren_i : in  std_logic;

      -- Port B
      b_memio_i       : in  std_logic_vector(8*32-1 downto 0);  -- To MEMIO
      b_memio_clear_i : in  std_logic_vector(  32-1 downto 0);
      b_memio_o       : out std_logic_vector(8*32-1 downto 0)   -- From MEMIO
   );
end memio;

architecture structural of memio is

   signal memio_r : std_logic_vector( 8*32-1 downto 0) := G_INIT_VAL;
   signal memio_s : std_logic_vector(16*32-1 downto 0);

begin

   memio_s <= b_memio_i & memio_r;
  
   -- Port A
   p_port_a : process (clk_i)
      variable addr_v : integer range 0 to 2**G_ADDR_BITS-1;
   begin
      if rising_edge(clk_i) then
         addr_v := to_integer(a_addr_i);

         if a_wren_i = '1' and a_addr_i(G_ADDR_BITS-1) = '0' then
            memio_r(addr_v*8+7 downto addr_v*8) <= a_data_i;
         end if;
         for i in 0 to 31 loop
            if b_memio_clear_i(i) = '1' then
               memio_r(8*i+7 downto 8*i) <= G_INIT_VAL(8*i+7 downto 8*i);
            end if;
         end loop;
         a_data_o <= memio_s(addr_v*8+7 downto addr_v*8);
      end if;
   end process p_port_a;

   -- Port B
   b_memio_o <= memio_r;

end structural;

