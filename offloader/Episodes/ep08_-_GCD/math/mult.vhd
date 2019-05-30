library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity mult is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val1_i  : in  std_logic_vector(G_SIZE-1 downto 0);
      val2_i  : in  std_logic_vector(G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_o   : out std_logic_vector(2*G_SIZE-1 downto 0);
      valid_o : out std_logic
   );
end mult;

architecture Behavioral of mult is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   signal mult_r   : std_logic_vector(G_SIZE-1 downto 0);
   signal add_r    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal res_r    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal valid_r  : std_logic;

   type fsm_state is (IDLE_ST, MULT_ST, DONE_ST);
   signal state_r  : fsm_state;

begin

   p_fsm : process (clk_i) is
   begin
      if rising_edge(clk_i) then
         valid_r <= '0';  -- Default value

         case state_r is
            when IDLE_ST =>
               if start_i = '1' then
                  mult_r <= val1_i;
                  add_r  <= val2_i;
                  res_r  <= C_ZERO;
                  state  <= MULT_ST;
               end if;

            when MULT_ST =>
               if mult_r(0) = '1' then
                  res_r <= res_r + add_r;
               end if;

               mult_r <= '0' & mult_r(G_SIZE-1 downto 1);
               add_r <= add_r(2*G_SIZE-2 downto 0) & '0';

               if mult_r = 0 then
                  state <= DONE_ST;
               end if;

            when DONE_ST =>
               valid_r <= '1';
               state_r <= IDLE_ST;

         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Connect output signals
   res_o   <= res_r;
   valid_o <= valid_r;

end Behavioral;

