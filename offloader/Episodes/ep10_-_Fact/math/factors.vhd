library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity factors is
   generic (
      G_NUM_FACTS  : integer;
      G_SIZE       : integer
   );
   port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;

      cf_res_x_i   : in  std_logic_vector(2*G_SIZE-1 downto 0);
      cf_res_p_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      cf_res_w_i   : in  std_logic;
      cf_valid_i   : in  std_logic;

      res_x_o      : out std_logic_vector(2*G_SIZE-1 downto 0);
      res_p_o      : out std_logic_vector(G_SIZE-1 downto 0);
      res_w_o      : out std_logic;
      res_fact_o   : out std_logic_vector(G_SIZE-1 downto 0);
      valid_o      : out std_logic
   );
end factors;

architecture Structural of factors is

   constant C_ZERO    : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   type primes_vector  is array (natural range <>) of std_logic_vector(G_SIZE-1 downto 0);

   constant C_PRIMES : primes_vector := (
      X"683ba8ff3e8b8a015e", -- 2*3*5*7*11*13*17*19*23*29*31*37*41*43*47*53*59
      X"485b2c5de43e46e77d", -- 61*67*71*73*79*83*89*97*101*103*107 
      X"79ccb68227152cf3c7", -- 109*113*127*131*137*139*149*151*157*163
      X"0f7904b436e31510f3", -- 167*173*179*181*191*193*197*199*211
      X"008b45a8fd62e4ee5d", -- 223*227*229*233*239*241*251*257
      X"020f33695f0d471f95"  -- 263*269*271*277*281*283*293*307
   );

   type t_fact_in is record
      x      : std_logic_vector(2*G_SIZE-1 downto 0);
      w      : std_logic;
      primes : std_logic_vector(G_SIZE-1 downto 0);
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

begin

   p_fact_idx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         for i in 0 to G_NUM_FACTS-1 loop
            fact_in(i).start <= '0';
         end loop;
         if cf_valid_i = '1' then
            if fact_out(fact_idx).busy = '0' then
               fact_in(fact_idx).start  <= '1';
               fact_in(fact_idx).val    <= cf_res_p_i;
               fact_in(fact_idx).w      <= cf_res_w_i;
               fact_in(fact_idx).x      <= cf_res_x_i;
               fact_in(fact_idx).primes <= C_PRIMES(0);

               if fact_idx < G_NUM_FACTS-1 then
                  fact_idx <= fact_idx + 1;
               else
                  fact_idx <= 0;
               end if;
            else
               report "Missed CF output.";
            end if;
         end if;

         if rst_i = '1' then
            fact_idx   <= 0;
         end if;
      end if;
   end process p_fact_idx;


   ----------------------------
   -- Instantiate FACT modules
   ----------------------------

   gen_facts : for i in 0 to G_NUM_FACTS-1 generate
      i_fact : entity work.fact
      generic map (
         G_SIZE   => G_SIZE
      )
      port map ( 
         clk_i    => clk_i,
         rst_i    => rst_i,
         primes_i => fact_in(i).primes,
         val_i    => fact_in(i).val,
         start_i  => fact_in(i).start,
         res_o    => fact_out(i).res,
         busy_o   => fact_out(i).busy,
         valid_o  => fact_out(i).valid
      ); -- i_fact
   end generate gen_facts;


   -- Arbitrate between possible results
   p_out : process (fact_in, fact_out)
      variable res_fact : std_logic_vector(G_SIZE-1 downto 0);
      variable res_p    : std_logic_vector(G_SIZE-1 downto 0);
      variable res_x    : std_logic_vector(2*G_SIZE-1 downto 0);
      variable res_w    : std_logic;
      variable valid    : std_logic;
   begin
      res_fact := (others => '0');
      res_w    := '0';
      res_p    := (others => '0');
      res_x    := (others => '0');
      valid    := '0';
      for i in 0 to G_NUM_FACTS-1 loop
         if fact_out(i).valid = '1' then
            if valid = '1' then
               report "Missed FACT output";
            end if;
            res_fact := fact_out(i).res;
            res_w    := fact_in(i).w;
            res_p    := fact_in(i).val;
            res_x    := fact_in(i).x;
            valid    := '1';
         end if;
      end loop;

      -- Connect output signals
      res_x_o    <= res_x;
      res_p_o    <= res_p;
      res_w_o    <= res_w;
      res_fact_o <= res_fact;
      valid_o    <= valid;
   end process p_out;

end Structural;

