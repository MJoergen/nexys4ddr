library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the integer square root module.

entity tb_sqrt is
end tb_sqrt;

architecture simulation of tb_sqrt is

   constant C_SIZE     : integer := 64;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal val          : std_logic_vector(2*C_SIZE-1 downto 0);
   signal start        : std_logic;
   signal res          : std_logic_vector(C_SIZE-1 downto 0);
   signal diff         : std_logic_vector(C_SIZE-1 downto 0);
   signal valid        : std_logic;

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

   i_sqrt : entity work.sqrt
   generic map (
      G_SIZE  => C_SIZE
   )
   port map (
      clk_i   => clk,
      rst_i   => rst,
      val_i   => val,
      start_i => start,
      res_o   => res,
      diff_o  => diff,
      valid_o => valid
   ); -- i_sqrt


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      function sqrt(v : integer) return integer is
         variable r : integer;
      begin
         r := 0;

         while r*r <= v loop
            r := r + 1;
         end loop;

         return r-1;
      end function sqrt;

      type tb_vector_t is array (natural range <>) of integer;

      -- Verify SQRT
      procedure verify_sqrt(tb : tb_vector_t) is
         variable exp_sqrt : integer;
         variable exp_diff : integer;
      begin

         report "Verify SQRT";

         for i in 0 to tb'length-1 loop
            -- Start calculation
            val   <= to_stdlogicvector(tb(i), 2*C_SIZE);
            start <= '1';
            wait until clk = '1';
            start <= '0';
            wait until clk = '1';

            -- Calculate expected response
            exp_sqrt := sqrt(tb(i));
            exp_diff := tb(i) - exp_sqrt*exp_sqrt;

            -- Verify received response is correct
            wait until clk = '1' and valid = '1';
            wait until clk = '0';
            assert res  = to_stdlogicvector(exp_sqrt, C_SIZE);
            assert diff = to_stdlogicvector(exp_diff, C_SIZE);

            wait until clk = '1' and valid = '0';
            wait until clk = '0';
         end loop;
      end procedure verify_sqrt;

      constant tb : tb_vector_t := (
            1,   2,    3,    4,    5,    6,    7,    8,
            9,  10,   11,   12,   13,   14,   15,   27,
          363, 465, 1293, 1758);

   begin
      -- Wait until reset is complete
      start <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify SQRT
      verify_sqrt(tb);
      wait for 20 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

