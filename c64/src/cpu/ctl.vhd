--------------------------------------
-- The Control Logic
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ctl is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      data_i : in  std_logic_vector( 7 downto 0);

      mem_rden_o      : out std_logic;    -- Read from memory
      mem_wren_o      : out std_logic;    -- Write to memory
      mem_addr_wren_o : out std_logic;    -- Write to address hold register
      mem_addr_sel_o  : out std_logic_vector(1 downto 0);   -- Memory address select
      mem_data_sel_o  : out std_logic_vector(1 downto 0);   -- Memory data select
      reg_wren_o      : out std_logic;    -- Write to register file
      reg_nr_o        : out std_logic_vector(1 downto 0);   -- Register number
      pc_sel_o        : out std_logic_vector(1 downto 0);   -- PC relect
      alu_func_o      : out std_logic_vector(3 downto 0);   -- ALU function
      clc_o           : out std_logic;                      -- Clear carry
      sr_alu_wren_o   : out std_logic;                      -- Write status register

      debug_o : out std_logic_vector(10 downto 0)
   );
end ctl;

architecture Structural of ctl is

   signal cnt_r  : std_logic_vector(2 downto 0);
   signal inst_r : std_logic_vector(7 downto 0);
   signal last   : std_logic;

begin

   debug_o( 7 downto 0) <= inst_r;
   debug_o(10 downto 8) <= cnt_r;

   -- Store the microinstruction counter
   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt_r <= cnt_r + 1;

         if rst_i = '1' or last = '1' then
            cnt_r <= (others => '0');
         end if;
      end if;
   end process p_cnt;


   -- Store the current instruction
   p_inst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if cnt_r = 0 then
            inst_r <= data_i;
         end if;
      end if;
   end process p_inst;


   -- Combinatorial process
   process (cnt_r, inst_r)
   begin
      -- Assign default values to avoid latch.
      mem_rden_o      <= '0';
      mem_wren_o      <= '0';
      mem_addr_wren_o <= '0';
      mem_addr_sel_o  <= "00";
      mem_data_sel_o  <= "00";
      reg_wren_o      <= '0';
      reg_nr_o        <= "00";
      pc_sel_o        <= "00";
      alu_func_o      <= "0000";
      clc_o           <= '0';
      sr_alu_wren_o   <= '0';

      last            <= '0';

      if cnt_r = 0 then
         mem_rden_o <= '1';            -- Read byte 0 from memory
      end if;

      -- The following line handles immediate operand addressing mode
      -- of the instructions ORA, AND, EOR, ADC, (STA), LDA, CMP, SBC.
      if cnt_r = 1 and inst_r(4 downto 0) = "01001" then
         mem_rden_o     <= '1';        -- Read byte 0 from memory
         alu_func_o     <= "0" & inst_r(7 downto 5); 
         sr_alu_wren_o  <= '1';
         reg_nr_o       <= "00";       -- Select register A
         reg_wren_o     <= '1';        -- Write to register
         last           <= '1';        -- Next instruction
      end if;

      -- The following lines handle zero page addressing mode
      -- of the instructions ORA, AND, EOR, ADC, STA, LDA, CMP, SBC.
      if cnt_r = 1 and inst_r(4 downto 0) = "00101" then
         mem_rden_o      <= '1';       -- Read byte 0 from memory
         mem_addr_wren_o <= '1';       -- Write to address hold register
      end if;

      if cnt_r = 2 and inst_r(4 downto 0) = "00101" then
         mem_rden_o     <= '1';        -- Read from memory
         mem_addr_sel_o <= "01";       -- Select z.p. address from hold register
         alu_func_o     <= "0" & inst_r(7 downto 5); 
         sr_alu_wren_o  <= '1';
         reg_nr_o       <= "00";       -- Select register A
         reg_wren_o     <= '1';        -- Write to register
         pc_sel_o       <= "11";       -- PC unchanged
         last           <= '1';        -- Next instruction
      end if;

      -- Override, in case of STA 
      if cnt_r = 2 and inst_r = X"85" then
         mem_rden_o     <= '0';        -- Don't read from memory
         mem_wren_o     <= '1';        -- Write to memory
         mem_data_sel_o <= "00";       -- Select register file
      end if;

      if cnt_r = 1 and inst_r = X"18" then   -- CLC
         pc_sel_o       <= "11";       -- PC unchanged
         clc_o          <= '1';        -- Clear carry
         last           <= '1';        -- Next instruction
      end if;

      if cnt_r = 1 and inst_r = X"4C" then   -- JMP $0404
         mem_rden_o      <= '1';       -- Read byte 0 from memory
         mem_addr_wren_o <= '1';       -- Write to address hold register
      end if;

      if cnt_r = 2 and inst_r = X"4C" then
         mem_rden_o      <= '1';       -- Read byte 0 from memory
         pc_sel_o        <= "01";      -- Jump
         last            <= '1';       -- Next instruction
      end if;

   end process;

end architecture Structural;

