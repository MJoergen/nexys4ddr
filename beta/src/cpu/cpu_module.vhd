library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cpu_module is
   port (
      -- Clock
      clk_i : in  std_logic;                    -- 100 MHz
      sw_i  : in  std_logic_vector(15 downto 0);
      val_o : out std_logic_vector(31 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   -- Program counter
   signal pc : std_logic_vector(31 downto 0) := (others => '0');

   signal alu_a   : std_logic_vector(31 downto 0);
   signal alu_b   : std_logic_vector(31 downto 0);
   signal alu_out : std_logic_vector(31 downto 0);
   signal alu_fn  : std_logic_vector( 5 downto 0);

begin

   -- Program counter
   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pc <= pc + 1;
      end if;
   end process p_pc;


   -- Arithmetic & Logic Unit
   i_alu : entity work.alu_module
   port map (
      alufn_i => alu_fn,
      a_i     => alu_a,
      b_i     => alu_b,
      alu_o   => alu_out,
      z_o     => open,
      v_o     => open,
      n_o     => open
   );

   -- Connect things up
   alu_fn <= sw_i(5 downto 0);
   alu_a  <= pc;
   alu_b  <= pc;
   val_o  <= alu_out;
 
end Structural;

