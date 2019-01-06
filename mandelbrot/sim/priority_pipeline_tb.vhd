library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity priority_pipeline_tb is
end entity priority_pipeline_tb;

architecture sim of priority_pipeline_tb is

   constant C_SIZE : integer := 16;
   constant C_SEED : integer := 1247;  -- Some random number

   signal clk    : std_logic;
   signal rst    : std_logic;

   signal vector_pipeline  : std_logic_vector(C_SIZE-1 downto 0);
   signal index_pipeline   : integer range 0 to C_SIZE-1;
   signal active_pipeline  : std_logic;

   signal vector_reference : std_logic_vector(C_SIZE-1 downto 0);
   signal index_reference  : integer range 0 to C_SIZE-1;
   signal active_reference : std_logic;

   -- Random number generator
   signal prbs255          : std_logic_vector(254 downto 0)
                             := to_std_logic_vector(C_SEED, 255);

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   --------------------------------------------
   -- Random number generator, based on a PRBS
   --------------------------------------------

   p_prbs255 : process (clk)
   begin
      if rising_edge(clk) then
         prbs255 <= prbs255(253 downto 0)
            & (prbs255(254) xor prbs255(13) xor prbs255(17) xor prbs255(126));
      end if;
   end process p_prbs255;
   

   -----------------------
   -- Generate test cases
   -----------------------

   p_vector : process (clk)
   begin
      if rising_edge(clk) then
         vector_reference <= vector_pipeline;   -- Must be delayed one clock cycle

--         vector_pipeline <= prbs255(C_SIZE-1 downto 0);
         vector_pipeline <= vector_pipeline + 1;

         if rst = '1' then
            vector_reference <= (others => '0');
            vector_pipeline  <= (others => '0');
         end if;
      end if;
   end process p_vector;


   -------------------
   -- Instantiate DUT
   -------------------

   i_priority_pipeline : entity work.priority_pipeline
   generic map (
      G_SIZE => C_SIZE
   )
   port map (
      clk_i    => clk,
      rst_i    => rst,
      vector_i => vector_pipeline,
      index_o  => index_pipeline,
      active_o => active_pipeline
   ); -- i_priority_pipeline


   -------------------------
   -- Instantiate reference
   -------------------------

   i_priority : entity work.priority
   generic map (
      G_SIZE => C_SIZE
   )
   port map (
      clk_i    => clk,
      rst_i    => rst,
      vector_i => vector_reference,
      index_o  => index_reference,
      active_o => active_reference
   ); -- i_priority


   -----------------
   -- Verify output
   -----------------

   p_verify : process (clk)
   begin
      if rising_edge(clk) then
         if rst = '0' then
            assert active_reference = active_pipeline
               report "'active' differs" severity error;

            if active_pipeline = '1' then
               assert index_reference = index_pipeline
                  report "'index' differs" severity error;
            end if;
         end if;
      end if;
   end process p_verify;

end architecture sim;

