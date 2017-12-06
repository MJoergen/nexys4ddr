library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity regfile is
   port (
      regs_o      : out std_logic_vector(1023 downto 0); -- Debug output
      cpu_clk_i   : in  std_logic;
      cpu_clken_i : in  std_logic;
      werf_i      : in  std_logic;
      ra2sel_i    : in  std_logic;
      ra_i        : in  std_logic_vector(   4 downto 0);
      rb_i        : in  std_logic_vector(   4 downto 0);
      rc_i        : in  std_logic_vector(   4 downto 0);
      wdata_i     : in  std_logic_vector(  31 downto 0);
      radata_o    : out std_logic_vector(  31 downto 0);
      rbdata_o    : out std_logic_vector(  31 downto 0)
   );
end regfile;

architecture Structural of regfile is

   signal regs : std_logic_vector(1023 downto 0) := (others => '0');

begin

   regs_o <= regs;

   -- 1 clocked write port
   p_regs : process (cpu_clk_i)
      variable reg : integer range 0 to 31;
   begin
      if rising_edge(cpu_clk_i) then
         if cpu_clken_i = '1' then
            if werf_i = '1' then
               if rc_i /= "11111" then -- Don't change R31.
                  reg := conv_integer(rc_i);
                  regs(reg*32 + 31 downto reg*32) <= wdata_i;
               end if;
            end if;
         end if;
      end if;
   end process p_regs;

   -- combinational read port.
   process (regs, ra_i)
      variable rega : integer range 0 to 31;
   begin
      rega := conv_integer(ra_i);
      radata_o <= regs(rega*32 + 31 downto rega*32);
   end process;

   -- combinational read port.
   process (regs, rb_i, rc_i, ra2sel_i)
      variable regb : integer range 0 to 31;
   begin
      if ra2sel_i = '0'  then
         regb := conv_integer(rb_i);
      else
         regb := conv_integer(rc_i);
      end if;
      rbdata_o <= regs(regb*32 + 31 downto regb*32);
   end process;

end Structural;

