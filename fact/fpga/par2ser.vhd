library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity par2ser is
   generic (
      G_PL_SIZE : integer := 60
   );
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Receive interface
      pl_valid_i : in  std_logic;
      pl_size_i  : in  std_logic_vector(7 downto 0);
      pl_data_i  : in  std_logic_vector(G_PL_SIZE*8-1 downto 0);

      -- Transmitinterface
      tx_valid_o : out std_logic;
      tx_sof_o   : out std_logic;
      tx_eof_o   : out std_logic;
      tx_data_o  : out std_logic_vector(7 downto 0)
   );
end par2ser;

architecture Structural of par2ser is

   type t_state is (IDLE_ST, FWD_ST);
   signal state_r : t_state := IDLE_ST;

   signal size_r : std_logic_vector(7 downto 0);
   signal data_r : std_logic_vector(G_PL_SIZE*8-1 downto 0);

   signal tx_valid_r : std_logic;
   signal tx_sof_r   : std_logic;
   signal tx_eof_r   : std_logic;
   signal tx_data_r  : std_logic_vector(7 downto 0);

begin

   p_state : process (clk_i)
   begin
      if rising_edge(clk_i) then
         tx_valid_r <= '0';
         tx_sof_r   <= '0';
         tx_eof_r   <= '0';
         tx_data_r  <= X"00";

         case state_r is
            when IDLE_ST =>
               if pl_valid_i = '1' then
                  assert pl_size_i >= 2 report "Frame size must be at least 2" severity failure;
                  tx_valid_r <= '1';
                  tx_sof_r   <= '1';
                  tx_eof_r   <= '0';
                  tx_data_r  <= pl_data_i(7 downto 0);
                  data_r     <= X"00" & pl_data_i(G_PL_SIZE*8-1 downto 8);
                  size_r     <= pl_size_i-1;
                  state_r    <= FWD_ST;
               end if;

            when FWD_ST =>
               tx_valid_r <= '1';
               tx_data_r  <= data_r(7 downto 0);
               data_r     <= X"00" & data_r(G_PL_SIZE*8-1 downto 8);
               size_r     <= size_r-1;
               if size_r-1 = 0 then
                  tx_eof_r <= '1';
                  state_r  <= IDLE_ST;
               end if;

         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
         end if;
      end if;
   end process p_state;

end Structural;

