library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pc is
   generic (
      G_RESET : std_logic_vector(31 downto 0) := X"80000000";
      G_ILLOP : std_logic_vector(31 downto 0) := X"80000004";
      G_XADDR : std_logic_vector(31 downto 0) := X"80000008"
   );
   port (
      cpu_clk_i   : in  std_logic;
      cpu_clken_i : in  std_logic;
      rstn_i      : in  std_logic;
      pcsel_i     : in  std_logic_vector( 2 downto 0);
      branch_i    : in  std_logic_vector(31 downto 0);
      jt_i        : in  std_logic_vector(31 downto 0);
      ia_o        : out std_logic_vector(31 downto 0);
      ia4_o       : out std_logic_vector(31 downto 0)
   );
end pc;

architecture Structural of pc is

   signal ia      : std_logic_vector(31 downto 0) := G_RESET;
   signal ia4     : std_logic_vector(31 downto 0);
   signal new_ia4 : std_logic_vector(31 downto 0);
   signal high_ia : std_logic_vector(31 downto 0);

   function preserve_mode (pc : std_logic_vector(31 downto 0);
      mode : std_logic) return std_logic_vector is
      variable res : std_logic_vector(31 downto 0);
   begin
      res := pc;
      res(31) := pc(31) and mode;
      return res;
   end function preserve_mode;


begin

   ia4     <= ia + 4;
   new_ia4 <= ia(31) & ia4(30 downto 0); -- Make sure bit 31 doesn't change.
   high_ia <= (31 => ia(31), others => '0');

   -- Program Counter aka Instruction Address
   p_ia : process (cpu_clk_i)
   begin
      if rising_edge(cpu_clk_i) then
         if cpu_clken_i = '1' then
            case pcsel_i is
               when "000" => ia <= new_ia4;
               when "001" => ia <= preserve_mode(branch_i, ia(31));
               when "010" => ia <= preserve_mode(jt_i, ia(31));
               when "011" => ia <= G_ILLOP;
               when "100" => ia <= G_XADDR;
               when others => report "Invalid pcsel" severity failure;
            end case;
         end if;

         if rstn_i = '0' then
            ia <= G_RESET;
         end if;
      end if;
   end process p_ia;

   ia_o  <= ia;
   ia4_o <= new_ia4;

end Structural;

