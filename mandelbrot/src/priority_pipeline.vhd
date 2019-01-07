library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a simple priority encoder.
-- There is room for improvement, in case the input vector is very large.

entity priority_pipeline is
   generic (
      G_SIZE      : integer
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      vector_i  : in  std_logic_vector(G_SIZE-1 downto 0);
      index_o   : out integer range 0 to G_SIZE-1;
      active_o  : out std_logic
   );
end entity priority_pipeline;

architecture rtl of priority_pipeline is

   function sqrt_int(arg : integer) return integer is
      variable res : integer;
   begin
      res := 1;
      while res*res < arg loop
         res := res * 2;
      end loop;
      return res;
   end function sqrt_int;

   constant C_FIRST : integer := sqrt_int(G_SIZE);

   -- Expand input vector
   signal vector_s : std_logic_vector(C_FIRST*C_FIRST-1 downto 0);

   -- Result from first level
   signal first_vector_s : std_logic_vector(C_FIRST-1 downto 0);
   signal first_index_r  : integer range 0 to C_FIRST-1;
   signal first_active_r : std_logic;

   -- Pipeline
   signal vector_d       : std_logic_vector(C_FIRST*C_FIRST-1 downto 0);
   signal first_index_d  : integer range 0 to C_FIRST-1;
   signal first_active_d : std_logic;

   -- Result from second level
   signal second_vector_s : std_logic_vector(C_FIRST-1 downto 0);
   signal second_index_r  : integer range 0 to C_FIRST-1;
   signal second_active_r : std_logic;

begin

   -- Expand input vector to a square matrix
   vector_s(G_SIZE-1 downto 0) <= vector_i;
   vector_s(C_FIRST*C_FIRST-1 downto G_SIZE) <= (others => '0');

   -- Generate input to first level
   g_first_vector : for i in 0 to C_FIRST-1 generate
      first_vector_s(i) <= '1' when vector_s((i+1)*C_FIRST-1 downto i*C_FIRST) /= 0 else '0';
   end generate g_first_vector;

   -- Find which row in matrix 
   i_priority_first : entity work.priority
      generic map (
         G_SIZE => C_FIRST
      )
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         vector_i => first_vector_s,
         index_o  => first_index_r,
         active_o => first_active_r
      ); -- i_priority_first

   -- Pipeline
   p_pipeline : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vector_d       <= vector_s;
         first_index_d  <= first_index_r;
         first_active_d <= first_active_r;
      end if;
   end process p_pipeline;

   -- Multiplexer
   second_vector_s <= vector_d((first_index_r+1)*C_FIRST-1 downto first_index_r*C_FIRST);

   -- Find which column in matrix 
   i_priority_second : entity work.priority
      generic map (
         G_SIZE => C_FIRST
      )
      port map (
         clk_i    => clk_i,
         rst_i    => rst_i,
         vector_i => second_vector_s,
         index_o  => second_index_r,
         active_o => second_active_r
      ); -- i_priority_second

   -- Generate output signals
   active_o <= first_active_d and second_active_r;
   index_o  <= first_index_d * C_FIRST + second_index_r;

end architecture rtl;

