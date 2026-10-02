library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-checking testbench for the pipelined priority encoder. It
-- compares priority_pipeline with the simple priority encoder (priority.vhd),
-- which is used as the reference. The input vector is a counter, so all
-- 2^C_SIZE input vectors are tested, which takes 655 us for C_SIZE = 16. The
-- testbench does not stop by itself, but is stopped by the maximum simulation
-- time in the Makefile (STOP_TIME).
--
-- The pipelined version has one more clock cycle of latency, so the input to
-- the reference is delayed by one clock cycle.

entity priority_pipeline_tb is
end entity priority_pipeline_tb;

architecture sim of priority_pipeline_tb is

   constant C_SIZE : integer := 16;

   signal clk    : std_logic;
   signal rst    : std_logic;

   signal vector_pipeline  : std_logic_vector(C_SIZE-1 downto 0);
   signal index_pipeline   : integer range 0 to C_SIZE-1;
   signal active_pipeline  : std_logic;

   signal vector_reference : std_logic_vector(C_SIZE-1 downto 0);
   signal index_reference  : integer range 0 to C_SIZE-1;
   signal active_reference : std_logic;

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


   -----------------------
   -- Generate test cases
   -----------------------

   p_vector : process (clk)
   begin
      if rising_edge(clk) then
         vector_reference <= vector_pipeline;   -- Must be delayed one clock cycle
         vector_pipeline  <= vector_pipeline + 1;

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

