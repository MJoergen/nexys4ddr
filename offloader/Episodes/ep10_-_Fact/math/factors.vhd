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

      cfg_primes_i    : in  std_logic_vector(7 downto 0);    -- Number of primes.
      cfg_factors_i   : in  std_logic_vector(7 downto 0);    -- Number of factors.
      mon_cf_o        : out std_logic_vector(31 downto 0);   -- Number of generated CF.
      mon_miss_cf_o   : out std_logic_vector(31 downto 0);   -- Number of missed CF.
      mon_miss_fact_o : out std_logic_vector(31 downto 0);   -- Number of missed FACT.
      mon_factored_o  : out std_logic_vector(31 downto 0);   -- Number of completely factored.
      mon_clkcnt_o    : out std_logic_vector(15 downto 0);   -- Average clock count factoring.

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

   constant C_RAM_ADDR_SIZE : integer := 6;
   constant C_RAM_DATA_SIZE : integer := 3*G_SIZE + 1;

   type t_fact_out is record
      res    : std_logic_vector(G_SIZE-1 downto 0);
      busy   : std_logic;
      valid  : std_logic;
      clkcnt : std_logic_vector(15 downto 0);
   end record t_fact_out;
   type fact_out_vector is array (natural range <>) of t_fact_out;

   signal start_vector  : std_logic_vector(G_NUM_FACTS-1 downto 0);
   signal fact_out      : fact_out_vector(G_NUM_FACTS-1 downto 0);
   signal fact_idx      : integer range 0 to G_NUM_FACTS-1;
   signal out_idx       : integer range 0 to G_NUM_FACTS-1;

   signal mon_cf        : std_logic_vector(31 downto 0);   -- Number of generated CF
   signal mon_miss_cf   : std_logic_vector(31 downto 0);   -- Number of missed CF
   signal mon_factored  : std_logic_vector(31 downto 0);   -- Number of completely factored.

   signal ram_wr_en     : std_logic;
   signal ram_wr_addr   : std_logic_vector(C_RAM_ADDR_SIZE-1 downto 0);
   signal ram_wr_data   : std_logic_vector(C_RAM_DATA_SIZE-1 downto 0);
   signal ram_rd_en     : std_logic;
   signal ram_rd_addr   : std_logic_vector(C_RAM_ADDR_SIZE-1 downto 0);
   signal ram_rd_data   : std_logic_vector(C_RAM_DATA_SIZE-1 downto 0);

begin

   -- Connect signals to RAM
   ram_wr_addr <= to_stdlogicvector(fact_idx, C_RAM_ADDR_SIZE);
   ram_wr_data <= cf_res_w_i & cf_res_p_i & cf_res_x_i;
   ram_wr_en   <= cf_valid_i and not fact_out(fact_idx).busy;
   ram_rd_en   <= fact_out(out_idx).valid;
   ram_rd_addr <= to_stdlogicvector(out_idx, C_RAM_ADDR_SIZE);

   gen_start : for i in 0 to G_NUM_FACTS-1 generate
      start_vector(i) <= ram_wr_en when i = fact_idx else '0';
   end generate gen_start;

   --------------------------------------------
   -- Input to fact_all modules is round-robin
   --------------------------------------------

   p_fact_idx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ram_wr_en = '1' then
            if fact_idx < cfg_factors_i-1 and fact_idx < G_NUM_FACTS-1 then
               fact_idx <= fact_idx + 1;
            else
               fact_idx <= 0;
            end if;
         end if;

         if rst_i = '1' then
            fact_idx <= 0;
         end if;
      end if;
   end process p_fact_idx;


   -----------------------------------------------
   -- Output from fact_all modules is round-robin
   -----------------------------------------------

   p_out_idx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if fact_out(out_idx).valid = '1' then
            if out_idx < cfg_factors_i-1 and out_idx < G_NUM_FACTS-1 then
               out_idx <= out_idx + 1;
            else
               out_idx <= 0;
            end if;
         end if;

         if rst_i = '1' then
            out_idx <= 0;
         end if;
      end if;
   end process p_out_idx;


   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid_o <= '0';
         if fact_out(out_idx).valid = '1' and fact_out(out_idx).res = 1 then
            valid_o <= '1';
         end if;
         if fact_out(out_idx).valid = '1' then
            mon_clkcnt_o <= fact_out(out_idx).clkcnt;
         end if;

         if rst_i = '1' then
            valid_o <= '0';
         end if;
      end if;
   end process p_out;

   res_x_o <= ram_rd_data(2*G_SIZE-1 downto 0);
   res_p_o <= ram_rd_data(3*G_SIZE-1 downto 2*G_SIZE);
   res_w_o <= ram_rd_data(3*G_SIZE);


   ---------------------------
   -- Update monitor counters
   ---------------------------

   p_mon : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cf_valid_i = '1' then
            mon_cf <= mon_cf + 1;
         end if;
         if cf_valid_i = '1' and fact_out(fact_idx).busy = '1' then
            mon_miss_cf <= mon_miss_cf + 1;
         end if;
         if valid_o = '1' then
            mon_factored <= mon_factored + 1;
         end if;

         if rst_i = '1' then
            mon_cf       <= (others => '0');
            mon_miss_cf  <= (others => '0');
            mon_factored <= (others => '0');
         end if;
      end if;
   end process p_mon;


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
         val_i     => cf_res_p_i,
         start_i   => start_vector(i),
         res_o     => fact_out(i).res,
         busy_o    => fact_out(i).busy,
         valid_o   => fact_out(i).valid,
         clkcnt_o  => fact_out(i).clkcnt
      ); -- i_fact
   end generate gen_facts;


   -------------------
   -- Instantiate RAM
   -------------------

   i_ram : entity work.ram
   generic map (
      G_ADDR_SIZE => C_RAM_ADDR_SIZE,
      G_DATA_SIZE => C_RAM_DATA_SIZE
   )
   port map ( 
      clk_i     => clk_i,
      rst_i     => rst_i,
      wr_en_i   => ram_wr_en,
      wr_addr_i => ram_wr_addr,
      wr_data_i => ram_wr_data,
      rd_en_i   => ram_rd_en,
      rd_addr_i => ram_rd_addr,
      rd_data_o => ram_rd_data
   ); -- i_ram


   -- Connect output signals
   mon_cf_o        <= mon_cf;
   mon_miss_cf_o   <= mon_miss_cf;
   mon_miss_fact_o <= (others => '0');
   mon_factored_o  <= mon_factored;

end Structural;

