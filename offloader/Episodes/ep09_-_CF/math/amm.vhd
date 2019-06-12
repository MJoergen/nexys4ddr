library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module performs Add, Mult, Mod, i.e.
-- it calculates a*x+b mod n

entity amm is
   generic (
      G_SIZE : integer
   );
   port ( 
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      val_a_i : in  std_logic_vector(G_SIZE-1 downto 0);
      val_x_i : in  std_logic_vector(2*G_SIZE-1 downto 0);
      val_b_i : in  std_logic_vector(2*G_SIZE-1 downto 0);
      val_n_i : in  std_logic_vector(2*G_SIZE-1 downto 0);
      start_i : in  std_logic;
      res_o   : out std_logic_vector(2*G_SIZE-1 downto 0);
      busy_o  : out std_logic;
      valid_o : out std_logic
   );
end amm;

architecture Behavioral of amm is

   constant C_ZERO : std_logic_vector(G_SIZE-1 downto 0) := (others => '0');

   signal mult_r   : std_logic_vector(G_SIZE-1 downto 0);
   signal add_r    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal res_r    : std_logic_vector(2*G_SIZE-1 downto 0);
   signal valid_r  : std_logic;

   type fsm_state is (IDLE_ST, MULT_ST);
   signal state_r  : fsm_state;

begin

   p_fsm : process (clk_i) is
   begin
      if rising_edge(clk_i) then

         case state_r is
            when IDLE_ST =>
               if start_i = '1' then
                  mult_r  <= val_a_i;
                  add_r   <= val_x_i;
                  res_r   <= val_b_i;
                  valid_r <= '0';
                  state_r <= MULT_ST;
               end if;

            when MULT_ST =>
               if mult_r(0) = '1' then
                  if res_r + add_r >= val_n_i then
                     res_r <= res_r + add_r - val_n_i;
                  else
                     res_r <= res_r + add_r;
                  end if;
               end if;

               mult_r <= '0' & mult_r(G_SIZE-1 downto 1);
               if add_r(2*G_SIZE-2 downto 0) & '0' >= val_n_i then
                  add_r <= add_r(2*G_SIZE-2 downto 0) & '0' - val_n_i;
               else
                  add_r <= add_r(2*G_SIZE-2 downto 0) & '0';
               end if;

               if mult_r = 0 then
                  valid_r <= '1';
                  state_r <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_fsm;

   -- Connect output signals
   res_o   <= res_r;
   valid_o <= valid_r;
   busy_o  <= '0' when state_r = IDLE_ST else '1';

end Behavioral;

