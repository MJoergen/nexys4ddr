-- This package has the types and the function used in the ports of the two
-- parts of the dispatcher (dispatcher_jobs.vhd and dispatcher_results.vhd).

library ieee;
use ieee.std_logic_1164.all;

package dispatcher_pkg is

   -- One value (cx, starty, or stepy) for each group of job modules
   type value_vector is array (natural range <>) of
      std_logic_vector(17 downto 0);

   -- The row within the job of the result of each job module
   type res_addr_vector is array (natural range <>) of
      std_logic_vector(8 downto 0);

   -- The number of bits needed for the values 0 to n-1
   function log2 (n : natural) return natural;

end package dispatcher_pkg;

package body dispatcher_pkg is

   function log2 (n : natural) return natural is
      variable r_v : natural := 0;
   begin
      while 2**r_v < n loop
         r_v := r_v + 1;
      end loop;
      return r_v;
   end function log2;

end package body dispatcher_pkg;
