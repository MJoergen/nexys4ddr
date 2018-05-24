library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity datapath is
   port (
      clk_i   : in  std_logic;
      wait_i  : in  std_logic;

      addr_o  : out std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector(7 downto 0);
      data_o  : out std_logic_vector(7 downto 0);
      wren_o  : out std_logic;

      ar_sel_i   : in  std_logic;
      hi_sel_i   : in  std_logic;
      lo_sel_i   : in  std_logic;
      pc_sel_i   : in  std_logic_vector(1 downto 0);
      addr_sel_i : in  std_logic_vector(1 downto 0);
      data_sel_i : in  std_logic_vector(1 downto 0);

      debug_o : out std_logic_vector(79 downto 0)
   );
end entity datapath;

architecture structural of datapath is

   -- Program Counter
   signal pc : std_logic_vector(15 downto 0) := (others => '0');

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0);

   -- Adress Hi register
   signal hi : std_logic_vector(7 downto 0);
   
   -- Adress Lo register
   signal lo : std_logic_vector(7 downto 0);

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
               when "00" => null;
               when "01" => pc <= pc + 1;
               when "10" => pc <= hi & lo;
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
   addr <= (others => '0') when addr_sel_i = "00" else
           pc              when addr_sel_i = "01" else
           hi & lo         when addr_sel_i = "10" else
           (others => '0');

   data <= (others => '0') when data_sel_i = "00" else
           ar              when data_sel_i = "01" else
           (others => '0');

   wren <= not wait_i when data_sel_i = "01" else
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
   wren_o <= wren;

end architecture structural;

