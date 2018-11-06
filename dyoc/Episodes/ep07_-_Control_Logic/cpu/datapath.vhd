library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity datapath is
   port (
      clk_i   : in  std_logic;

      -- Memory interface
      wait_i  : in  std_logic;
      addr_o  : out std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector(7 downto 0);
      data_o  : out std_logic_vector(7 downto 0);
      wren_o  : out std_logic;

      -- Control signals
      ar_sel_i   : in  std_logic;
      hi_sel_i   : in  std_logic;
      lo_sel_i   : in  std_logic;
      pc_sel_i   : in  std_logic_vector(1 downto 0);
      addr_sel_i : in  std_logic_vector(1 downto 0);
      data_sel_i : in  std_logic_vector(1 downto 0);

      -- Debug output containing internal registers
      debug_o : out std_logic_vector(79 downto 0)
   );
end entity datapath;

architecture structural of datapath is

   constant PC_NOP   : std_logic_vector(1 downto 0) := B"00";
   constant PC_INC   : std_logic_vector(1 downto 0) := B"01";
   constant PC_HL    : std_logic_vector(1 downto 0) := B"10";
   --
   constant ADDR_NOP : std_logic_vector(1 downto 0) := B"00";
   constant ADDR_PC  : std_logic_vector(1 downto 0) := B"01";
   constant ADDR_HL  : std_logic_vector(1 downto 0) := B"10";
   --
   constant DATA_NOP : std_logic_vector(1 downto 0) := B"00";
   constant DATA_AR  : std_logic_vector(1 downto 0) := B"01";
   

   -- Program Counter
   signal pc : std_logic_vector(15 downto 0) := (others => '0');

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0);

   -- Address Hi register
   signal hi : std_logic_vector(7 downto 0);
   
   -- Address Lo register
   signal lo : std_logic_vector(7 downto 0);

   -- Output signals to memory
   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector(7 downto 0);
   signal wren : std_logic;
   
begin

   -- Program Counter
   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case pc_sel_i is
               when PC_NOP => null;
               when PC_INC => pc <= pc + 1;
               when PC_HL  => pc <= hi & lo;
               when others => null;
            end case;
         end if;
      end if;
   end process p_pc;

   -- 'A' register
   p_ar : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if ar_sel_i = '1' then
               ar <= data_i;
            end if;
         end if;
      end if;
   end process p_ar;

   -- 'Hi' register
   p_hi : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if hi_sel_i = '1' then
               hi <= data_i;
            end if;
         end if;
      end if;
   end process p_hi;

   -- 'Lo' register
   p_lo : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if lo_sel_i = '1' then
               lo <= data_i;
            end if;
         end if;
      end if;
   end process p_lo;


   -- Output multiplexers
   addr <= (others => '0') when addr_sel_i = ADDR_NOP else
           pc              when addr_sel_i = ADDR_PC  else
           hi & lo         when addr_sel_i = ADDR_HL  else
           (others => '0');

   data <= (others => '0') when data_sel_i = DATA_NOP else
           ar              when data_sel_i = DATA_AR  else
           (others => '0');

   wren <= '1' when data_sel_i = DATA_AR else
           '0';


   -----------------
   -- Drive output signals
   -----------------

   debug_o(15 downto  0) <= pc;     -- Two bytes
   debug_o(23 downto 16) <= ar;     -- One byte
   debug_o(31 downto 24) <= data_i; -- One byte
   debug_o(39 downto 32) <= lo;     -- One byte
   debug_o(47 downto 40) <= hi;     -- One byte
   debug_o(63 downto 48) <= addr;   -- Two bytes
   debug_o(71 downto 64) <= data;   -- One byte
   debug_o(72)           <= wren;   -- One byte
   debug_o(79 downto 73) <= (others => '0');

   addr_o <= addr;
   data_o <= data;
   wren_o <= wren and not wait_i;

end architecture structural;

