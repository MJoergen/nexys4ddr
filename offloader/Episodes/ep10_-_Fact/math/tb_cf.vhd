library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Continued Fraction module.

entity tb_cf is
end tb_cf;

architecture simulation of tb_cf is

   constant C_SIZE     : integer := 72;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal cf_val_n     : std_logic_vector(2*C_SIZE-1 downto 0);
   signal cf_start     : std_logic;
   signal cf_res_x     : std_logic_vector(2*C_SIZE-1 downto 0);
   signal cf_res_p     : std_logic_vector(C_SIZE-1 downto 0);
   signal cf_res_w     : std_logic;
   signal cf_valid     : std_logic;

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

   i_cf : entity work.cf
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk,
      rst_i   => rst,
      val_i   => cf_val_n,
      start_i => cf_start,
      res_x_o => cf_res_x,
      res_p_o => cf_res_p,
      res_w_o => cf_res_w,
      valid_o => cf_valid
   ); -- i_cf


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
                          res    : res_vector_t) is
         variable exp_x : std_logic_vector(2*C_SIZE-1 downto 0);
         variable exp_p : std_logic_vector(C_SIZE-1 downto 0);
         variable exp_w : std_logic;
      begin

         report "Verify CF: N=" & integer'image(val_n);

         wait until clk = '0';
         cf_val_n <= to_stdlogicvector(val_n, 2*C_SIZE);
         cf_start <= '1';
         wait until clk = '1';
         cf_start <= '0';
         wait until clk = '1';

         for i in 0 to res'length-1 loop
            report "Verifying response (" & integer'image(res(i).x) &
               ", " & integer'image(res(i).y) & ")";

            -- Verify received response is correct
            wait until clk = '1' and cf_valid = '1';
            wait until clk = '0';
            exp_x := to_stdlogicvector(res(i).x, 2*C_SIZE);
            if res(i).y > 0 then
               exp_p := to_stdlogicvector(res(i).y, C_SIZE);
               exp_w := '0';
            else
               exp_p := to_stdlogicvector(-res(i).y, C_SIZE);
               exp_w := '1';
            end if;
            assert cf_res_x = exp_x and
                   cf_res_p = exp_p and
                   cf_res_w = exp_w
               report "Received (" & to_string(cf_res_x) & ", " & to_string(cf_res_w) & ", " & to_string(cf_res_p) & ")";

            wait until clk = '1' and cf_valid = '0';
            wait until clk = '0';

         end loop;

      end procedure verify_cf;

      -- These values are copied from the spread sheet cf.xlsx.
      constant res2059 : res_vector_t := (
         (  45, -34),
         (  91,  45),
         ( 136, -35),
         ( 227,  54),
         ( 363,  -7),
         ( 465,  30),
         (1293, -59),
         (1758,   5),
         ( 294, -42),
         ( 287,   9),
         ( 818, -51),
         (1105,  38),
         (1923, -35),
         ( 833,   6),
         (1231, -63),
         (   5,  25));

      constant res2623 : res_vector_t := (
         (  51, -22),
         ( 205,  57),
         ( 256, -39),
         ( 461,  58),
         ( 717, -19),
         ( 706,  66),
         (1423, -27),
         ( 929,  74),
         (2352,  -3),
         (2478,  41),
         (2062, -39),
         (1356,  13));

      constant res3922201 : res_vector_t := (
         (   1980, -1801),
         (   3961,   717),
         (  21785,   -96),
         ( 897146,   307),
         (2943135, -3240),
         (3840281,   489),
         (2369695,  -685),
         (3922153,  2304),
         (2369647, -1443),
         (2369599,  2407),
         ( 817045,  -376),
         (1878602,  3217),
         (2695647,  -453),
         (1137126,  3000),
         (3832773,  -655),
         ( 689986,   615),
         ( 128287, -1027));

   begin
      -- Wait until reset is complete
      cf_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify CF
      verify_cf(2623, res2623);
      wait for 200 ns;

      verify_cf(2059, res2059);
      wait for 200 ns;

      verify_cf(3922201, res3922201);
      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

