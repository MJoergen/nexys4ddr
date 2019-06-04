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
   signal alg_cf_res_x  : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_cf_res_y  : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_cf_valid  : std_logic;
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
      cf_res_x_o  => alg_cf_res_x,
      cf_res_y_o  => alg_cf_res_y,
      cf_valid_o  => alg_cf_valid,
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

      -- Verify CF processing
      procedure verify_cf(val_n  : integer;
                          val_x  : integer;
                          val_y  : integer;
                          res    : res_vector_t) is
      begin

         report "Verify CF: N=" & integer'image(val_n) & 
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

         for i in 0 to res'length-1 loop
            report "Verifying response (" & integer'image(res(i).x) &
               ", " & integer'image(res(i).y) & ")";

            -- Verify received response is correct
            wait until clk = '1' and alg_cf_valid = '1';
            wait until clk = '0';
            assert alg_cf_res_x = to_stdlogicvector(res(i).x, 2*C_SIZE) and
                   alg_cf_res_y = to_stdlogicvector(res(i).y, C_SIZE)
               report "Received (" & to_string(alg_cf_res_x) & ", " & to_string(alg_cf_res_y) & ")";

            wait until clk = '1' and alg_cf_valid = '0';
            wait until clk = '0';

         end loop;

      end procedure verify_cf;

      -- These values are copied from the spread sheet cf.xlsx.
      constant res2059 : res_vector_t := (
         (  91, 45),
         ( 136, 35),
         ( 227, 54),
         ( 363,  7),
         ( 465, 30),
         (1293, 59),
         (1758,  5),
         ( 294, 42),
         ( 287,  9),
         ( 818, 51),
         (1105, 38),
         (1923, 35),
         ( 833,  6),
         (1231, 63),
         (   5, 25));

      constant res2623 : res_vector_t := (
         ( 205, 57),
         ( 256, 39),
         ( 461, 58),
         ( 717, 19),
         ( 706, 66),
         (1423, 27),
         ( 929, 74),
         (2352,  3),
         (2478, 41),
         (2062, 39),
         (1356, 13));

      constant res3922201 : res_vector_t := (
         (   3961, 717),
         (  21785, 96),
         ( 897146, 307),
         (2943135, 3240),
         (3840281, 489),
         (2369695, 685),
         (3922153, 2304),
         (2369647, 1443),
         (2369599, 2407),
         ( 817045, 376),
         (1878602, 3217),
         (2695647, 453),
         (1137126, 3000),
         (3832773, 655),
         ( 689986, 615),
         ( 128287, 1027));

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

      -- Verify CF
      verify_cf(2623, 51, 22, res2623);
      wait for 200 ns;

      wait until clk = '0';
      alg_val_n <= (others => '0');
      alg_valid <= '1';
      wait until clk = '1';
      alg_valid <= '0';
      wait until clk = '1';
      wait for 200 ns;

      verify_cf(2059, 45, 34, res2059);
      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

