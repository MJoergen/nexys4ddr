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
      alu_sel_i  : in  std_logic_vector(2 downto 0);
      sr_sel_i   : in  std_logic_vector(3 downto 0);

      -- Debug output containing internal registers
      debug_o : out std_logic_vector(95 downto 0)
   );
end entity datapath;

architecture structural of datapath is

   -- Output from ALU
   signal alu_ar : std_logic_vector(7 downto 0);
   signal alu_sr : std_logic_vector(7 downto 0);
   
   -- Program Counter
   signal pc : std_logic_vector(15 downto 0) := (others => '0');

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0);

   -- Status register
   signal sr : std_logic_vector(7 downto 0);

   -- Address Hi register
   signal hi : std_logic_vector(7 downto 0);
   
   -- Address Lo register
   signal lo : std_logic_vector(7 downto 0);

   -- Output signals to memory
   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector(7 downto 0);
   signal wren : std_logic;

begin

   -- Instantiate ALU
   i_alu : entity work.alu
   port map (
      a_i    => ar,
      b_i    => data_i,
      sr_i   => sr,
      func_i => alu_sel_i,
      a_o    => alu_ar,
      sr_o   => alu_sr
   );

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
               ar <= alu_ar;
            end if;
         end if;
      end if;
   end process p_ar;

   -- 'S' register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sr_sel_i is
               when "0000" => null;
               when "0001" => sr <= alu_sr;
               when "1000" => sr <= sr and X"FE";  -- CLC
               when "1001" => sr <= sr or  X"01";  -- SEC
               when "1010" => sr <= sr and X"FB";  -- CLI 
               when "1011" => sr <= sr or  X"04";  -- SEI
               when "1100" => sr <= sr and X"BF";  -- CLV
               when "1110" => sr <= sr and X"F7";  -- CLD
               when "1111" => sr <= sr or  X"08";  -- SED
               when others => null;
            end case;
         end if;
      end if;
   end process p_sr;

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

   wren <= '1' when data_sel_i = "01" else
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
   debug_o(87 downto 80) <= sr;     -- One byte
   debug_o(95 downto 88) <= (others => '0');

   addr_o <= addr;
   data_o <= data;
   wren_o <= wren;

end architecture structural;

