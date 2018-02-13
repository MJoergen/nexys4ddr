--------------------------------------
-- The top level CPU (6502 look-alike)
--
-- This current interface description has separate ports for data input and
-- output, but only one is used at any given time.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity cpu_module is
   port (
      -- Clock
      clk_i : in  std_logic;
      rst_i : in  std_logic;

      -- Memory and I/O interface
      addr_o : out std_logic_vector(15 downto 0);
      --
      rden_o : out std_logic;
      data_i : in  std_logic_vector(7 downto 0);
      --
      wren_o : out std_logic;
      data_o : out std_logic_vector(7 downto 0);

      -- Interrupt
      irq_i  : in  std_logic;

      -- Debug (to show on the VGA)
      debug_o : out std_logic_vector(127 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   -- Signals connected to ALU
   signal alu_a_in : std_logic_vector(7 downto 0);
   signal alu_out  : std_logic_vector(7 downto 0);
   signal alu_c    : std_logic;
   signal alu_s    : std_logic;
   signal alu_v    : std_logic;
   signal alu_z    : std_logic;

   -- Program Registers
   signal reg_sp : std_logic_vector( 7 downto 0) := (others => '0');
   signal reg_pc : std_logic_vector(15 downto 0) := (others => '0');
   signal reg_sr : std_logic_vector( 7 downto 0) := (others => '0');

   -- Signals connected to the register file
   signal regs_rd_data : std_logic_vector(7 downto 0);
   signal regs_debug   : std_logic_vector(23 downto 0);

   -- Additional Registers
   signal mem_addr_reg  : std_logic_vector(15 downto 0) := (others => '0');
   signal mem_addr2_reg : std_logic_vector(15 downto 0) := (others => '0');

   signal irq_masked : std_logic;

   -- This file contains the following registers:
   -- Register File (A, X, Y). Input is always from ALU. Requires ALU function
   --    code (4 bits).
   -- Program Counter. Input is either (PC + 4) or (mem_addr_reg) (1 bit).
   -- Stack Pointer. Input is either (SP + 1) or (SP - 1) (1 bit).
   -- Memory Address. Input is always data_i. 1 bit for each of hi and lo. (2 bits).
   -- Status Register, NZCV. Input is always from ALU. 1 bit for each (4 bits).
   -- Status Register, BID. 2 bits for each (6 bits).
   -- Status Register, All. Input is either register or memory (1 bit).

   -- Signals driven by the Control Logic
   signal ctl_wr_reg        : std_logic_vector(5 downto 0);
   signal ctl_wr_pc         : std_logic_vector(5 downto 0);
   signal ctl_wr_sp         : std_logic_vector(1 downto 0);
   signal ctl_wr_hold_addr  : std_logic_vector(1 downto 0);
   signal ctl_wr_hold_addr2 : std_logic_vector(1 downto 0);
   signal ctl_wr_szcv       : std_logic_vector(3 downto 0);
   signal ctl_wr_b          : std_logic_vector(1 downto 0);
   signal ctl_wr_i          : std_logic_vector(1 downto 0);
   signal ctl_wr_d          : std_logic_vector(1 downto 0);
   signal ctl_wr_sr         : std_logic_vector(1 downto 0);

   -- Additionally, some MUX's:
   signal ctl_mem_addr     : std_logic_vector(3 downto 0);
   signal ctl_mem_rden     : std_logic;
   signal ctl_reg_nr_wr    : std_logic_vector(1 downto 0);
   signal ctl_reg_nr_rd    : std_logic_vector(1 downto 0);

   -- Memory write data. Input is Register, PC, or SR (2 bits).
   signal ctl_mem_wrdata   : std_logic_vector(2 downto 0);
   signal ctl_wr_c         : std_logic_vector(1 downto 0);

   signal ctl_debug : std_logic_vector(10 downto 0);

   signal addr : std_logic_vector(15 downto 0);
   signal data : std_logic_vector( 7 downto 0);

begin

   irq_masked <= irq_i and not reg_sr(2);

   -- Instantiate the control logic
   inst_ctl : entity work.ctl
   port map (
               clk_i           => clk_i,
               rst_i           => rst_i,
               irq_i           => irq_masked,
               data_i          => data_i,
               wr_reg_o        => ctl_wr_reg,
               wr_pc_o         => ctl_wr_pc,
               wr_sp_o         => ctl_wr_sp,
               wr_hold_addr_o  => ctl_wr_hold_addr,
               wr_szcv_o       => ctl_wr_szcv,
               wr_b_o          => ctl_wr_b,
               wr_i_o          => ctl_wr_i,
               wr_d_o          => ctl_wr_d,
               wr_sr_o         => ctl_wr_sr,
               mem_addr_o      => ctl_mem_addr,
               mem_rden_o      => ctl_mem_rden,
               reg_nr_wr_o     => ctl_reg_nr_wr,
               reg_nr_rd_o     => ctl_reg_nr_rd,
               mem_wrdata_o    => ctl_mem_wrdata,
               wr_c_o          => ctl_wr_c,
               wr_hold_addr2_o => ctl_wr_hold_addr2,
               debug_o         => ctl_debug
            );

   -- Instantiate register file
   inst_regs : entity work.regs
   port map ( 
               clk_i       => clk_i,
               rst_i       => rst_i,
               reg_nr_wr_i => ctl_reg_nr_wr,
               reg_nr_rd_i => ctl_reg_nr_rd,
               data_o      => regs_rd_data,
               wren_i      => ctl_wr_reg(4),
               data_i      => alu_out,
               debug_o     => regs_debug
            );

   -- Instantiate the ALU (combinatorial)
   inst_alu : entity work.alu
   port map (
               a_i    => alu_a_in,
               b_i    => data_i,
               c_i    => reg_sr(0),  -- Carry
               func_i => ctl_wr_reg(3 downto 0),
               res_o  => alu_out,
               c_o    => alu_c,
               s_o    => alu_s,
               v_o    => alu_v,
               z_o    => alu_z
            );

   alu_a_in <= regs_rd_data when ctl_wr_reg(5) = '0' else reg_sp;


   -- Program Counter register
   p_pc : process (clk_i)
      function sign_extend(arg : std_logic_vector(7 downto 0))
      return std_logic_vector is
         variable res : std_logic_vector(15 downto 0);
      begin
         res := (others => arg(7)); -- Copy sign bit to all bits.
         res(7 downto 0) := arg;
         return res;
      end function sign_extend;
   begin
      if rising_edge(clk_i) then
         case ctl_wr_pc(1 downto 0) is
            when "01" =>
               reg_pc <= mem_addr_reg;                            -- Used during JSR
            when "10" =>
               reg_pc <= data_i & mem_addr_reg(7 downto 0);       -- Used during jump absolute
            when "11" =>
               reg_pc <= reg_pc + 1;                              -- Used during instruction fetch
               if ctl_wr_pc(2) = '1' then
                  if (ctl_wr_pc(5 downto 3) = "000" and reg_sr(7) = '0') or
                  (ctl_wr_pc(5 downto 3) = "001" and reg_sr(7) = '1') or
                  (ctl_wr_pc(5 downto 3) = "010" and reg_sr(6) = '0') or
                  (ctl_wr_pc(5 downto 3) = "011" and reg_sr(6) = '1') or
                  (ctl_wr_pc(5 downto 3) = "100" and reg_sr(0) = '0') or
                  (ctl_wr_pc(5 downto 3) = "101" and reg_sr(0) = '1') or
                  (ctl_wr_pc(5 downto 3) = "110" and reg_sr(1) = '0') or
                  (ctl_wr_pc(5 downto 3) = "111" and reg_sr(1) = '1') then
                     reg_pc <= reg_pc + 1 + sign_extend(data_i);  -- Used during branch relative
                  end if;
               end if;
            when others => null;
         end case;
      end if;
   end process p_pc;

   -- Stack pointer
   p_sp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case ctl_wr_sp is
            when "01" => reg_sp <= regs_rd_data;
            when "10" => reg_sp <= reg_sp - 1;
            when "11" => reg_sp <= reg_sp + 1;
            when others => null;
         end case;

         if rst_i = '1' then
            reg_sp <= X"FF";
         end if;
      end if;
   end process p_sp;


   -- Memory address hold register
   p_mem_addr_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case ctl_wr_hold_addr is
            when "01" => mem_addr_reg( 7 downto 0) <= data_i;           -- Used during zero-page addressing mode
                         mem_addr_reg(15 downto 8) <= (others => '0');
            when "10" => mem_addr_reg(15 downto 8) <= data_i;           -- Used during absolute addressing modes
            when "11" => mem_addr_reg <= mem_addr_reg + regs_rd_data;   -- Used during indirect addressing
            when others => null;
         end case;
      end if;
   end process p_mem_addr_reg;

   -- Second memory address hold register
   p_mem_addr2_reg : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case ctl_wr_hold_addr2 is
            when "10" => mem_addr2_reg( 7 downto 0) <= data_i + regs_rd_data;  -- Used during zero-page addressing mode
                         mem_addr2_reg(15 downto 8) <= (others => '0');
            when "11" => mem_addr2_reg( 7 downto 0) <= mem_addr2_reg( 7 downto 0) + 1;
            when others => null;
         end case;
      end if;
   end process p_mem_addr2_reg;


   -- Status register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ctl_wr_szcv(3) = '1' then
            reg_sr(7) <= alu_s;
         end if;

         if ctl_wr_szcv(2) = '1' then
            reg_sr(1) <= alu_z;
         end if;

         if ctl_wr_szcv(1) = '1' then
            reg_sr(0) <= alu_c;
         end if;

         if ctl_wr_szcv(0) = '1' then
            reg_sr(6) <= alu_v;
         end if;

         if ctl_wr_b(1) = '1' then
            reg_sr(4) <= ctl_wr_b(0);
         end if;

         if ctl_wr_c(1) = '1' then
            reg_sr(0) <= ctl_wr_c(0);
         end if;

         if ctl_wr_i(1) = '1' then
            reg_sr(2) <= ctl_wr_i(0);
         end if;

         if ctl_wr_d(1) = '1' then
            reg_sr(3) <= ctl_wr_d(0);
         end if;

         if ctl_wr_sr(1) = '1' then
            if ctl_wr_sr(0) = '1' then
               reg_sr <= data_i;          -- Used during RTI
            else
               reg_sr <= regs_rd_data;    -- Not currently used ????
            end if;
         end if;

         if rst_i = '1' then
            reg_sr <= X"04";              -- Interrupts are disabled after reset.
         end if;
      end if;
   end process p_sr;

 
   -- Select memory address
   addr <= reg_pc                           when ctl_mem_addr = "0000" else    -- Used during instruction fetch
           mem_addr_reg                     when ctl_mem_addr = "0001" else    -- Used during zero-page and absolute addressing
           X"01" & reg_sp                   when ctl_mem_addr = "0010" else    -- Used during stack push and pull
           mem_addr2_reg                    when ctl_mem_addr = "0011" else    -- Used during other addressing modes
           X"FFFE"                          when ctl_mem_addr = "1000" else    -- BRK
           X"FFFF"                          when ctl_mem_addr = "1001" else    -- BRK
           X"FFFA"                          when ctl_mem_addr = "1010" else    -- NMI
           X"FFFB"                          when ctl_mem_addr = "1011" else    -- NMI
           X"FFFC"                          when ctl_mem_addr = "1100" else    -- RESET
           X"FFFD"                          when ctl_mem_addr = "1101" else    -- RESET
           X"FFFE"                          when ctl_mem_addr = "1110" else    -- IRQ
           X"FFFF"                          when ctl_mem_addr = "1111" else    -- IRQ
           (others => 'X');

   -- Select memory data
   data <= regs_rd_data        when ctl_mem_wrdata(1 downto 0) = "00" else     -- Used during register store to memory
           reg_pc(15 downto 8) when ctl_mem_wrdata(1 downto 0) = "01" else     -- Used during IRQ
           reg_pc(7 downto 0)  when ctl_mem_wrdata(1 downto 0) = "10" else     -- Used during IRQ
           reg_sr              when ctl_mem_wrdata(1 downto 0) = "11" else     -- Used during IRQ
           (others => '0');


   -----------------------
   -- Drive output signals
   -----------------------

   addr_o <= addr;
   data_o <= data;
   rden_o <= ctl_mem_rden;
   wren_o <= ctl_mem_wrdata(2);

   -- Debug output
   debug_o( 15 downto   0) <= addr;                                     -- "ADDR"
   debug_o( 31 downto  16) <= "0000000" & ctl_mem_wrdata(2) & data;     -- "WR_DATA"
   debug_o( 47 downto  32) <= "0000000" & ctl_mem_rden & data_i;        -- "RD_DATA"
   debug_o( 63 downto  48) <= reg_pc;                                   -- "PC"
   debug_o( 79 downto  64) <= "00000" & ctl_debug;                      -- "INST"
   debug_o( 95 downto  80) <= reg_sr & regs_debug(7 downto 0);          -- "SR_A"
   debug_o(111 downto  96) <= regs_debug(23 downto 8);                  -- "X_Y"
   debug_o(127 downto 112) <= X"01" & reg_sp;                           -- "SP"

end Structural;

