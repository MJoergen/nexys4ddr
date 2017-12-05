library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity regfile is
   port (
      cpu_clk_i : in  std_logic;
      werf_i    : in  std_logic;
      ra2sel_i  : in  std_logic;
      ra_i      : in  std_logic_vector( 4 downto 0);
      rb_i      : in  std_logic_vector( 4 downto 0);
      rc_i      : in  std_logic_vector( 4 downto 0);
      wdata_i   : in  std_logic_vector(31 downto 0);
      radata_o  : out std_logic_vector(31 downto 0);
      rbdata_o  : out std_logic_vector(31 downto 0)
   );
end regfile;

architecture Structural of regfile is

   type MEM_TYPE is array (0 to 31) of std_logic_vector(31 downto 0);
   signal regs : MEM_TYPE := (others => (others => '0'));

begin

   -- 1 clocked write port
   p_regs : process (cpu_clk_i)
   begin
      if rising_edge(cpu_clk_i) then
         if werf_i = '1' then
            if rc_i /= "11111" then -- Don't change R31.
               regs(conv_integer(rc_i)) <= wdata_i;
            end if;
         end if;
      end if;
   end process p_regs;

   -- 2 combinational read ports.
   radata_o <= regs(conv_integer(ra_i));
   rbdata_o <= regs(conv_integer(rb_i)) when ra2sel_i = '0'
               else regs(conv_integer(rc_i));

end Structural;

