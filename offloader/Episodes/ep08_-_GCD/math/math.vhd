library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module is a small test module that inverts everything received.

entity math is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      debug_o    : out std_logic_vector(255 downto 0);

      -- Ingress to client
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress from client
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end math;

architecture Structural of math is

   constant C_SIZE      : integer := 32;
   constant C_ZERO      : std_logic_vector(C_SIZE-1 downto 0) := (others => '0');
   constant C_ZERO_HALF : std_logic_vector(C_SIZE/2-1 downto 0) := (others => '0');

   signal cmd           : std_logic_vector(15 downto 0);

   signal val1          : std_logic_vector(C_SIZE-1 downto 0);
   signal val2          : std_logic_vector(C_SIZE-1 downto 0);
   signal val3          : std_logic_vector(C_SIZE-1 downto 0);
   signal val4          : std_logic_vector(C_SIZE-1 downto 0);

   signal mult_start    : std_logic;
   signal mult_res      : std_logic_vector(C_SIZE-1 downto 0);
   signal mult_valid    : std_logic;

   signal gcd_start     : std_logic;
   signal gcd_res       : std_logic_vector(C_SIZE-1 downto 0);
   signal gcd_valid     : std_logic;

   signal divmod_start  : std_logic;
   signal divmod_res_q  : std_logic_vector(C_SIZE-1 downto 0);
   signal divmod_res_r  : std_logic_vector(C_SIZE-1 downto 0);
   signal divmod_valid  : std_logic;

   signal cf_start      : std_logic;
   signal cf_res_x      : std_logic_vector(C_SIZE-1 downto 0);
   signal cf_res_y      : std_logic_vector(C_SIZE/2-1 downto 0);
   signal cf_valid      : std_logic;

   signal amm_start     : std_logic;
   signal amm_res       : std_logic_vector(C_SIZE-1 downto 0);
   signal amm_valid     : std_logic;

   signal res           : std_logic_vector(2*C_SIZE-1 downto 0);
   signal valid         : std_logic;

   signal debug         : std_logic_vector(255 downto 0);

begin

   -- We just ignore rx_last_i and rx_bytes_i.
   cmd   <= rx_data_i(60*8-1          downto 58*8);
   val1  <= rx_data_i(58*8-1          downto 58*8-C_SIZE);
   val2  <= rx_data_i(58*8-1-C_SIZE   downto 58*8-C_SIZE*2);
   val3  <= rx_data_i(58*8-1-2*C_SIZE downto 58*8-C_SIZE*3);
   val4  <= rx_data_i(58*8-1-3*C_SIZE downto 58*8-C_SIZE*4);

   mult_start   <= rx_valid_i when cmd = X"0101" else '0';
   gcd_start    <= rx_valid_i when cmd = X"0102" else '0';
   divmod_start <= rx_valid_i when cmd = X"0103" else '0';
   amm_start    <= rx_valid_i when cmd = X"0104" else '0';
   cf_start     <= rx_valid_i when cmd = X"0105" else '0';

   i_mult : entity work.mult
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => val1,
      val2_i  => val2,
      start_i => mult_start,
      res_o   => mult_res,
      valid_o => mult_valid
   ); -- i_mult

   i_gcd : entity work.gcd
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val1_i  => val1,
      val2_i  => val2,
      start_i => gcd_start,
      res_o   => gcd_res,
      valid_o => gcd_valid
   ); -- i_gcd

   i_divmod : entity work.divmod
   generic map (
      G_SIZE => C_SIZE
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_n_i => val1,
      val_d_i => val2,
      start_i => divmod_start,
      res_q_o => divmod_res_q,
      res_r_o => divmod_res_r,
      valid_o => divmod_valid
   ); -- i_divmod

   i_amm : entity work.amm
   generic map (
      G_SIZE => C_SIZE/2
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_a_i => val1(C_SIZE/2-1 downto 0),
      val_x_i => val2,
      val_b_i => val3,
      val_n_i => val4,
      start_i => amm_start,
      res_o   => amm_res,
      valid_o => amm_valid
   ); -- i_amm

   i_cf : entity work.cf
   generic map (
      G_SIZE => C_SIZE/2
   )
   port map ( 
      clk_i   => clk_i,
      rst_i   => rst_i,
      val_n_i => val1,
      val_m_i => val2(C_SIZE/2-1 downto 0),
      val_y_i => val3(C_SIZE/2-1 downto 0),
      start_i => cf_start,
      res_x_o => cf_res_x,
      res_y_o => cf_res_y, 
      valid_o => cf_valid
   );

   valid <= mult_valid   or
            gcd_valid    or
            divmod_valid or
            cf_valid     or
            amm_valid;

   res   <= mult_res     & C_ZERO                                   or
            gcd_res      & C_ZERO                                   or
            divmod_res_q & divmod_res_r                             or
            cf_res_x     & cf_res_y & C_ZERO_HALF                   or
            amm_res      & C_ZERO;

   tx_valid_o <= valid;
   tx_data_o(60*8-1        downto 60*8-2*C_SIZE) <= res;
   tx_data_o(60*8-1-2*C_SIZE downto 0)           <= (others => '0');
   tx_bytes_o <= to_stdlogicvector(18, 6);
   tx_last_o  <= '1';

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' then
            debug <= rx_data_i(60*8-1 downto 60*8-256);
         end if;
         if valid = '1' then
            debug <= (others => '0');
            debug(2*C_SIZE-1 downto 0) <= res;
         end if;
      end if;
   end process p_debug;

   -- Connect output signal
   debug_o <= debug;

end Structural;

