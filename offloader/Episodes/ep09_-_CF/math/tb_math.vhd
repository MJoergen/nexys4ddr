library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Math module.

entity tb_math is
end tb_math;

architecture simulation of tb_math is

   constant C_SIZE     : integer := 72;
   constant C_ZERO     : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals conected to DUT
   signal cmd          : t_sim;
   signal resp         : t_sim;
   signal debug        : std_logic_vector(255 downto 0);

   signal exp          : t_sim;

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

   i_math : entity work.math
   generic map (
      G_SIZE     => C_SIZE
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      debug_o    => debug,
      rx_valid_i => cmd.valid,
      rx_data_i  => cmd.data,
      rx_last_i  => cmd.last,
      rx_bytes_i => cmd.bytes,
      tx_valid_o => resp.valid,
      tx_data_o  => resp.data,
      tx_last_o  => resp.last,
      tx_bytes_o => resp.bytes
   ); -- i_math


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
      procedure send(val_n  : integer) is
      begin

         wait until clk = '0';
         report "Send";
         cmd.valid <= '1';
         cmd.data  <= (others => '0');
         cmd.data(60*8-1 downto 60*8-2*C_SIZE) <=
            to_stdlogicvector(val_n, 2*C_SIZE);
         cmd.last  <= '1';
         cmd.bytes <= to_stdlogicvector(2*C_SIZE/8, 6);
         wait until clk = '1';
         cmd.valid <= '0';
         wait until clk = '1';
      end procedure send;

      -- Verify CF processing
      procedure verify_cf(val_n  : integer;
                          res    : res_vector_t) is
      begin

         report "Verify CF: N=" & integer'image(val_n);

         send(val_n);

         for i in 0 to res'length-1 loop
            report "Verifying response (" & integer'image(res(i).x) &
               ", " & integer'image(res(i).y) & ")";

            -- Build expected response
            exp.data  <= (others => '0');
            exp.data(60*8-1 downto 60*8-2*C_SIZE) <= to_stdlogicvector(res(i).x, 2*C_SIZE);

            if res(i).y > 0 then
               exp.data(60*8-1-2*C_SIZE downto 60*8-3*C_SIZE) <= to_stdlogicvector(res(i).y, C_SIZE);
            else
               exp.data(60*8-1-2*C_SIZE downto 60*8-3*C_SIZE) <= (not to_stdlogicvector(-res(i).y, C_SIZE)) + 1;
            end if;
            exp.data(60*8-1-3*C_SIZE downto 60*8-3*C_SIZE-32) <= to_stdlogicvector(i, 32);
            exp.last  <= '1';
            exp.bytes <= to_stdlogicvector(3*C_SIZE/8+4, 6);

            -- Verify received response is correct
            wait until clk = '1' and resp.valid = '1';
            wait until clk = '0';
            assert resp.data  = exp.data;
            assert resp.last  = exp.last;
            assert resp.bytes = exp.bytes;
            wait until clk = '1' and resp.valid = '0';
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

   begin
      -- Wait until reset is complete
      cmd.valid <= '0';
      wait until clk = '1' and rst = '0';

      -- Verify CF
      verify_cf(2623, res2623);
      wait for 10 ns;
      verify_cf(2059, res2059);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

