library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_alg is
end tb_alg;

architecture simulation of tb_alg is

   constant C_SIZE      : integer := 72;
   constant C_NUM_FACTS : integer := 10;

   signal clk           : std_logic;
   signal rst           : std_logic;

   -- Signals conected to DUT
   signal alg_val       : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_start     : std_logic;
   signal alg_res_x     : std_logic_vector(2*C_SIZE-1 downto 0);
   signal alg_res_p     : std_logic_vector(C_SIZE-1 downto 0);
   signal alg_res_w     : std_logic;
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
      val_i       => alg_val,
      start_i     => alg_start,
      res_x_o     => alg_res_x,
      res_p_o     => alg_res_p,
      res_w_o     => alg_res_w,
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
      procedure verify_fact(val_n  : integer) is
         variable res_x : integer;                               
         variable res_p : integer;                               
         variable res_w : std_logic;                               
         variable res_f : integer;                               
      begin

         report "Verify FACT: N=" & integer'image(val_n);

         wait until clk = '0';
         alg_val   <= to_stdlogicvector(val_n, 2*C_SIZE);
         alg_start <= '1';
         wait until clk = '1';
         alg_start <= '0';
         wait until clk = '1';

         while true loop
            wait until clk = '1';
            if alg_res_valid = '1' then
               res_x := to_integer(alg_res_x);
               res_p := to_integer(alg_res_p);
               res_w := alg_res_w;
               res_f := to_integer(alg_res_fact);

               report "x=" & integer'image(res_x) & ", " &
                  "p=" & integer'image(res_p) & ", " &
                  "w=" & std_logic'image(res_w) & ", " &
                  "f=" & integer'image(res_f);

               if res_w = '0' then
                  assert (res_x * res_x - res_p) mod val_n = 0;
               else
                  assert (res_x * res_x + res_p) mod val_n = 0;
               end if;
               assert res_p mod res_f = 0;
            end if;

         end loop;

      end procedure verify_fact;

   begin
      -- Wait until reset is complete
      alg_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify FACT
      verify_fact(31861);
      wait;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

