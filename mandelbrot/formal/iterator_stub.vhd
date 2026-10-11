-- This is a replacement for the iterator (src/main/iterator.vhd), used for
-- the formal verification of the job module. It has the same entity, so the
-- job module instantiates it instead of the real iterator, but it does not
-- calculate anything: Its outputs are chosen freely by the solver in every
-- clock cycle. The handshake of the iterator is instead given by assumptions
-- in job.psl, on the signals of the job module that are connected to the
-- iterator. This way, the state of the iterator (whether it is iterating) is
-- in job.psl, where it can be related to the state of the job module, which
-- is needed for the induction.

library ieee;
use ieee.std_logic_1164.all;

entity iterator is
   generic (
      G_MAX_COUNT : positive
   );
   port (
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      start_i : in  std_logic;
      cx_i    : in  std_logic_vector(17 downto 0);
      cy_i    : in  std_logic_vector(17 downto 0);
      cnt_o   : out std_logic_vector( 8 downto 0);
      done_o  : out std_logic
   );
end entity iterator;

architecture stub of iterator is

   signal any_cnt_s  : std_logic_vector(8 downto 0);
   signal any_done_s : std_logic;

   attribute anyseq : boolean;
   attribute anyseq of any_cnt_s  : signal is true;
   attribute anyseq of any_done_s : signal is true;

begin

   cnt_o  <= any_cnt_s;
   done_o <= any_done_s;

end architecture stub;
