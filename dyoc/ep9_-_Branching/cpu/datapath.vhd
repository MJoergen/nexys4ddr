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
      pc_sel_i   : in  std_logic_vector(4 downto 0);
      addr_sel_i : in  std_logic_vector(1 downto 0);
      data_sel_i : in  std_logic_vector(1 downto 0);
      alu_sel_i  : in  std_logic_vector(2 downto 0);
      sr_sel_i   : in  std_logic_vector(3 downto 0);

      -- Debug output containing internal registers
      debug_o : out std_logic_vector(95 downto 0)
   );
end entity datapath;

architecture structural of datapath is

   -- The Status Register contains: SV-BDIZC
   constant SR_C : integer := 0;
   constant SR_Z : integer := 1;
   constant SR_I : integer := 2;
   constant SR_D : integer := 3;
   constant SR_B : integer := 4;
   constant SR_R : integer := 5;    -- Bit 5 is reserved.
   constant SR_V : integer := 6;
   constant SR_S : integer := 7;

   -- Convert signed 8-bit number to signed 16-bit number
   function sign_extend(arg : std_logic_vector(7 downto 0))
   return std_logic_vector is
      variable res : std_logic_vector(15 downto 0);
   begin
      res := (others => arg(7)); -- Copy sign bit to all bits.
      res(7 downto 0) := arg;
      return res;
   end function sign_extend;

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
            case pc_sel_i(1 downto 0) is
               when "00" => null;
               when "01" => pc <= pc + 1;
               when "10" => pc <= hi & lo;
               when "11" =>
                  if (pc_sel_i(4 downto 2) = "000" and sr(SR_S) = '0') or     -- BPL
                     (pc_sel_i(4 downto 2) = "001" and sr(SR_S) = '1') or     -- BMI
                     (pc_sel_i(4 downto 2) = "010" and sr(SR_V) = '0') or     -- BVC
                     (pc_sel_i(4 downto 2) = "011" and sr(SR_V) = '1') or     -- BVS
                     (pc_sel_i(4 downto 2) = "100" and sr(SR_C) = '0') or     -- BCC
                     (pc_sel_i(4 downto 2) = "101" and sr(SR_C) = '1') or     -- BCS
                     (pc_sel_i(4 downto 2) = "110" and sr(SR_Z) = '0') or     -- BNE
                     (pc_sel_i(4 downto 2) = "111" and sr(SR_Z) = '1') then   -- BEQ
                     pc <= pc + 1 + sign_extend(data_i);
                  else
                     pc <= pc + 1;  -- If branch is not taken, just go to the next instruction.
                  end if;
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

   -- Status register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            case sr_sel_i is
               when "0000" => null;
               when "0001" => sr <= alu_sr;
               when "1000" => sr(SR_C) <= '0';  -- CLC
               when "1001" => sr(SR_C) <= '1';  -- SEC
               when "1010" => sr(SR_I) <= '0';  -- CLI 
               when "1011" => sr(SR_I) <= '1';  -- SEI
               when "1100" => sr(SR_V) <= '0';  -- CLV
               when "1110" => sr(SR_D) <= '0';  -- CLD
               when "1111" => sr(SR_D) <= '1';  -- SED
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

