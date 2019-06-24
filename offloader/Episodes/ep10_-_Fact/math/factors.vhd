library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity factors is
   generic (
      G_NUM_FACTS     : integer;
      G_SIZE          : integer
   );
   port (
      clk_i           : in  std_logic;
      rst_i           : in  std_logic;

      cfg_primes_i    : in  std_logic_vector(3 downto 0);    -- Number of primes.
      cfg_factors_i   : in  std_logic_vector(7 downto 0);    -- Number of factors.
      mon_cf_o        : out std_logic_vector(31 downto 0);   -- Number of generated CF.
      mon_miss_cf_o   : out std_logic_vector(31 downto 0);   -- Number of missed CF.
      mon_miss_fact_o : out std_logic_vector(31 downto 0);   -- Number of missed FACT.
      mon_factored_o  : out std_logic_vector(31 downto 0);   -- Number of completely factored.

      cf_res_x_i      : in  std_logic_vector(2*G_SIZE-1 downto 0);
      cf_res_p_i      : in  std_logic_vector(G_SIZE-1 downto 0);
      cf_res_w_i      : in  std_logic;
      cf_valid_i      : in  std_logic;

      res_x_o         : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_p_o         : out std_logic_vector(G_SIZE-1 downto 0);
      res_w_o         : out std_logic;
      valid_o         : out std_logic
   );
end factors;

architecture Structural of factors is

   type t_fact_in is record
      x      : std_logic_vector(2*G_SIZE-1 downto 0);
      w      : std_logic;
      val    : std_logic_vector(G_SIZE-1 downto 0);
      start  : std_logic;
   end record t_fact_in;
   type fact_in_vector is array (natural range <>) of t_fact_in;
   type t_fact_out is record
      res    : std_logic_vector(G_SIZE-1 downto 0);
      busy   : std_logic;
      valid  : std_logic;
   end record t_fact_out;
   type fact_out_vector is array (natural range <>) of t_fact_out;

   signal fact_in  : fact_in_vector(G_NUM_FACTS-1 downto 0);
   signal fact_out : fact_out_vector(G_NUM_FACTS-1 downto 0);
   signal fact_idx : integer range 0 to G_NUM_FACTS-1;

   signal out_idx  : std_logic_vector(4 downto 0);
   signal valid    : std_logic;

   signal mon_cf        : std_logic_vector(31 downto 0);   -- Number of generated CF
   signal mon_miss_cf   : std_logic_vector(31 downto 0);   -- Number of missed CF
   signal mon_miss_fact : std_logic_vector(31 downto 0);   -- Number of missed FACT
   signal mon_factored  : std_logic_vector(31 downto 0);   -- Number of completely factored.

begin

   -- Dispatch command to next avaiable fact_all nmodule in a round-robin
   -- scheme,
   p_fact_idx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         for i in 0 to G_NUM_FACTS-1 loop
            fact_in(i).start <= '0';
         end loop;

         if cf_valid_i = '1' then
            mon_cf <= mon_cf + 1;
            if fact_out(fact_idx).busy = '0' then
               fact_in(fact_idx).start <= '1';
               fact_in(fact_idx).val   <= cf_res_p_i;
               fact_in(fact_idx).w     <= cf_res_w_i;
               fact_in(fact_idx).x     <= cf_res_x_i;

               -- Select next fact_all module.
               if fact_idx < cfg_factors_i-1 then
                  fact_idx <= fact_idx + 1;
               else
                  fact_idx <= 0;
               end if;
            else
               mon_miss_cf <= mon_miss_cf + 1;
               report "Missed CF output.";
            end if;
         end if;

         if rst_i = '1' then
            fact_idx    <= 0;
            mon_cf      <= (others => '0');
            mon_miss_cf <= (others => '0');
         end if;
      end if;
   end process p_fact_idx;


   ----------------------------
   -- Instantiate FACT modules
   ----------------------------

   gen_facts : for i in 0 to G_NUM_FACTS-1 generate
      i_fact_all : entity work.fact_all
      generic map (
         G_SIZE   => G_SIZE
      )
      port map ( 
         clk_i     => clk_i,
         rst_i     => rst_i,
         primes_i  => cfg_primes_i,
         val_i     => fact_in(i).val,
         start_i   => fact_in(i).start,
         res_o     => fact_out(i).res,
         busy_o    => fact_out(i).busy,
         valid_o   => fact_out(i).valid
      ); -- i_fact
   end generate gen_facts;


   -- Arbitrate between possible results
   p_out : process (clk_i)
      variable out_idx_v : std_logic_vector(4 downto 0);
      variable valid_v   : std_logic;
   begin
      if rising_edge(clk_i) then
         valid_v  := '0';

         for i in 0 to G_NUM_FACTS-1 loop
            if fact_out(i).valid = '1' then
               if valid = '1' then
                  report "Missed FACT output";
                  mon_miss_fact <= mon_miss_fact + 1;
               else
                  -- Only indicate 'valid' when the y-value is completely factored.
                  if fact_out(i).res = 1 then
                     out_idx_v    := to_stdlogicvector(i, 5);
                     valid_v      := '1';
                     mon_factored <= mon_factored + 1;
                  end if;
               end if;
            end if;
         end loop;

         out_idx <= out_idx_v;
         valid   <= valid_v;

         if rst_i = '1' then
            mon_miss_fact <= (others => '0');
            mon_factored  <= (others => '0');
         end if;
      end if;
   end process p_out;

   res_w_o <= fact_in(to_integer(out_idx)).w;
   res_p_o <= fact_in(to_integer(out_idx)).val;
   res_x_o <= fact_in(to_integer(out_idx)).x;
   valid_o <= valid;

   -- Connect output signals
   mon_cf_o        <= mon_cf;
   mon_miss_cf_o   <= mon_miss_cf;
   mon_miss_fact_o <= mon_miss_fact;
   mon_factored_o  <= mon_factored;

end Structural;

