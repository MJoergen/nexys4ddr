library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Jacobi module.

entity tb_jacobi is
end tb_jacobi;

architecture simulation of tb_jacobi is

   constant C_SIZE     : integer := 64;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal jb_val_n     : std_logic_vector(C_SIZE-1 downto 0);
   signal jb_val_k     : std_logic_vector(C_SIZE-1 downto 0);
   signal jb_start     : std_logic;
   signal jb_res       : std_logic_vector(C_SIZE-1 downto 0);
   signal jb_valid     : std_logic;
   signal jb_busy      : std_logic;

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

   i_jacobi : entity work.jacobi
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk,
      rst_i   => rst,
      val_n_i => jb_val_n,
      val_k_i => jb_val_k,
      start_i => jb_start,
      res_o   => jb_res,
      valid_o => jb_valid,
      busy_o  => jb_busy
   ); -- i_jacobi


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      type res_t is record
         n : integer;
         k : integer;
         j : integer;
      end record res_t;
      type res_vector_t is array (natural range <>) of res_t;      

      -- Verify Jacobi processing
      procedure verify_jacobi(res : res_vector_t) is
         variable exp : std_logic_vector(C_SIZE-1 downto 0);
      begin

         for i in 0 to res'length-1 loop
            report "Verify CF: k=" & integer'image(res(i).k) & 
               ", n=" & integer'image(res(i).n) & 
               ", J=" & integer'image(res(i).j);

            wait until clk = '0';
            jb_val_n <= to_stdlogicvector(res(i).n, C_SIZE);
            jb_val_k <= to_stdlogicvector(res(i).k, C_SIZE);
            jb_start <= '1';
            wait until clk = '1';
            jb_start <= '0';
            wait until clk = '1';
            wait until clk = '0';
            assert jb_busy = '1';
            assert jb_valid = '0';

            exp := (others => '0');
            if res(i).j = 1 then
               exp := to_stdlogicvector(1, C_SIZE);
            elsif res(i).j = -1 then
               exp := (others => '1');
            end if;

            -- Verify received response is correct
            wait until clk = '1' and jb_valid = '1';
            wait until clk = '0';
            assert jb_res = exp
               report "Received " & to_string(jb_res);

         end loop;

      end procedure verify_jacobi;

      constant res_vector : res_vector_t := (
         (   1,    1,   1),
         (   2,    1,   1),
         (   3,    1,   1),
         (   4,    1,   1),
         (   5,    1,   1),
         (   6,    1,   1),
         (   7,    1,   1),

         (   1,    3,   1),
         (   2,    3,  -1),
         (   3,    3,   0),
         (   4,    3,   1),
         (   5,    3,  -1),
         (   6,    3,   0),
         (   7,    3,   1),

         (   1,    5,   1),
         (   2,    5,  -1),
         (   3,    5,  -1),
         (   4,    5,   1),
         (   5,    5,   0),
         (   6,    5,   1),
         (   7,    5,  -1),

         (   5,   21,   1),
         (   8,   21,  -1),
         (  19,   45,   1),
         (  30,    7,   1),
         (  30,   11,  -1),
         (  30,   13,   1),
         (1001, 9907,  -1));

   begin
      -- Wait until reset is complete
      jb_start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify Jacobi
      verify_jacobi(res_vector);
      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

