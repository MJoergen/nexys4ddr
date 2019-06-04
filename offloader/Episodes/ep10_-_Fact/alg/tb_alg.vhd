library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_alg is
end tb_alg;

architecture simulation of tb_alg is

   constant C_SIZE      : integer := 64;
   constant C_NUM_FACTS : integer := 5;

   signal clk           : std_logic;
   signal rst           : std_logic;

   -- Signals conected to DUT
   signal alg_val_n     : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_val_x     : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_val_y     : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_valid     : std_logic;
   signal alg_res_x     : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_res_y     : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_res_neg   : std_logic;
   signal alg_res_fact  : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_res_valid : std_logic;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

begin

   --------------------------------------------------
   -- Generate clock and reset
   --------------------------------------------------

   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns; -- 50 MHz
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;


   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------

   i_alg : entity work.alg
   generic map (
      G_NUM_FACTS => C_NUM_FACTS,
      G_SIZE      => C_SIZE
   )
   port map (
      clk_i       => clk,
      rst_i       => rst,
      val_n_i     => alg_val_n,
      val_x_i     => alg_val_x,
      val_y_i     => alg_val_y,
      valid_i     => alg_valid,
      res_x_o     => alg_res_x,
      res_y_o     => alg_res_y,
      res_neg_o   => alg_res_neg,
      res_fact_o  => alg_res_fact,
      valid_o     => alg_res_valid
   ); -- i_alg


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      type res_t is record
         x : integer;
         y : integer;
      end record res_t;
      type res_vector_t is array (natural range <>) of res_t;      

      -- Verify FACT processing
      procedure verify_fact(val_n  : integer;
                            val_x  : integer;
                            val_y  : integer) is
         variable res_x   : integer;                               
         variable res_y   : integer;                               
         variable res_neg : std_logic;                               
         variable res_f   : integer;                               
      begin

         report "Verify FACT: N=" & integer'image(val_n) & 
            ", X=" & integer'image(val_x) & 
            ", Y=" & integer'image(val_y);

         assert val_n - val_x*val_x = val_y;

         wait until clk = '0';
         alg_val_n <= to_stdlogicvector(val_n, 2*C_SIZE);
         alg_val_x <= to_stdlogicvector(val_x, C_SIZE);
         alg_val_y <= to_stdlogicvector(val_y, C_SIZE);
         alg_valid <= '1';
         wait until clk = '1';
         alg_valid <= '0';
         wait until clk = '1';

         while true loop
            wait until clk = '1';
            if alg_res_valid = '1' then
               res_x   := to_integer(alg_res_x);
               res_y   := to_integer(alg_res_y);
               res_neg := alg_res_neg;
               res_f   := to_integer(alg_res_fact);

               report "x=" & integer'image(res_x) & ", " &
                  "y=" & integer'image(res_y) & ", " &
                  "f=" & integer'image(res_f);

               if res_neg = '0' then
                  assert (res_x * res_x - res_y) mod val_n = 0;
               else
                  assert (res_x * res_x + res_y) mod val_n = 0;
               end if;
               assert res_y mod res_f = 0;
            end if;

         end loop;

      end procedure verify_fact;

   begin
      -- Wait until reset is complete
      alg_valid <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify FACT
      verify_fact(31861, 178, 177);
      wait;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

