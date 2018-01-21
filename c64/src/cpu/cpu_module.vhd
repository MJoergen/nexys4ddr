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
      debug_o : out std_logic_vector(63 downto 0)
   );
end cpu_module;

architecture Structural of cpu_module is

   -- Signals connected to ALU
   signal alu_a    : std_logic_vector(7 downto 0);
   signal alu_b    : std_logic_vector(7 downto 0);
   signal alu_out  : std_logic_vector(7 downto 0);
   signal alu_c    : std_logic;
   signal alu_s    : std_logic;
   signal alu_v    : std_logic;
   signal alu_z    : std_logic;

   -- Signals driven by the Control Logic
   signal ctl_mem_rden      : std_logic;                       -- Read from memory
   signal ctl_mem_wren      : std_logic;                       -- Write to memory
   signal ctl_mem_addr_wren : std_logic_vector(1 downto 0);    -- Write to address hold register
   signal ctl_mem_addr_sel  : std_logic_vector(3 downto 0);    -- Memory address select
   signal ctl_mem_data_sel  : std_logic_vector(1 downto 0);    -- Memory data select
   signal ctl_reg_wren      : std_logic;                       -- Write to register file
   signal ctl_reg_nr        : std_logic_vector(1 downto 0);    -- Register number
   signal ctl_pc_sel        : std_logic_vector(1 downto 0);    -- PC select
   signal ctl_alu_func      : std_logic_vector(3 downto 0);    -- ALU function
   signal ctl_clc           : std_logic;                       -- Clear carry
   signal ctl_sr_alu_wren   : std_logic;                       -- Update status register
   signal ctl_sp_sel        : std_logic_vector(1 downto 0);    -- Stack pointer update
   signal ctl_irq_mask_wr   : std_logic_vector(1 downto 0);    -- IRQ mask write
   signal ctl_debug         : std_logic_vector(10 downto 0);   -- Microinstruction counter.

   -- Program Registers
   signal reg_sp : std_logic_vector( 7 downto 0);
   signal reg_pc : std_logic_vector(15 downto 0);
   signal reg_sr : std_logic_vector( 7 downto 0);

   -- Signals connected to the register file
   signal regs_rd_data : std_logic_vector(7 downto 0);
   signal regs_wr_data : std_logic_vector(7 downto 0);
   signal regs_debug   : std_logic_vector(23 downto 0);

   -- Additional Registers
   signal mem_addr_reg : std_logic_vector(15 downto 0);

   signal irq_masked : std_logic;

begin
 
   -- Internal checking
   assert ctl_mem_rden /= '1' or ctl_mem_wren /= '1'
      report "Simultaneous read and write"
      severity failure;

   -- First operand to ALU is typically a register
   alu_a <= regs_rd_data;

   -- Second operand to ALU is typically memory input
   alu_b <= data_i;

   -- Input to the register file is directly from the ALU.
   regs_wr_data <= alu_out;

   -- Instantiate the ALU (combinatorial)
   inst_alu : entity work.alu
   port map (
               a_i    => alu_a,
               b_i    => alu_b,
               c_i    => reg_sr(0),  -- Carry
               func_i => ctl_alu_func,
               res_o  => alu_out,
               c_o    => alu_c,
               s_o    => alu_s,
               v_o    => alu_v,
               z_o    => alu_z
            );

   -- Instantiate the control logic
   inst_ctl : entity work.ctl
   port map (
               clk_i           => clk_i,
               rst_i           => rst_i,
               irq_i           => irq_masked,
               data_i          => data_i,
               mem_rden_o      => ctl_mem_rden,
               mem_wren_o      => ctl_mem_wren,
               mem_addr_wren_o => ctl_mem_addr_wren,
               mem_addr_sel_o  => ctl_mem_addr_sel,
               mem_data_sel_o  => ctl_mem_data_sel,
               reg_wren_o      => ctl_reg_wren,
               reg_nr_o        => ctl_reg_nr,
               pc_sel_o        => ctl_pc_sel,
               sp_sel_o        => ctl_sp_sel,
               alu_func_o      => ctl_alu_func,
               clc_o           => ctl_clc,
               sr_alu_wren_o   => ctl_sr_alu_wren,
               irq_mask_wr_o   => ctl_irq_mask_wr,
               debug_o         => ctl_debug
            );

   irq_masked <= irq_i and not reg_sr(2);

   -- Instantiate register file
   inst_regs : entity work.regs
   port map ( 
               clk_i    => clk_i,
               rst_i    => rst_i,
               reg_nr_i => ctl_reg_nr,
               data_o   => regs_rd_data,
               wren_i   => ctl_reg_wren,
               data_i   => regs_wr_data,
               debug_o  => regs_debug
            );


   -- Program Counter register
   p_pc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case ctl_pc_sel is
            when "00" => reg_pc <= reg_pc + 1;
            when "01" => reg_pc(15 downto 8) <= data_i;
                         reg_pc( 7 downto 0) <= mem_addr_reg(7 downto 0);
            when "11" => null;
            when others => assert false severity failure;
         end case;
      end if;
   end process p_pc;


   -- Stack pointer
   p_sp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         case ctl_sp_sel is
            when "00" => null;
            when "01" => reg_sp <= reg_sp + 1;
            when "10" => reg_sp <= reg_sp - 1;
            when others => assert false severity failure;
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
         if ctl_mem_addr_wren(0) = '1' then
            mem_addr_reg(7 downto 0) <= data_i;
         end if;
         if ctl_mem_addr_wren(1) = '1' then
            mem_addr_reg(15 downto 8) <= data_i;
         end if;
      end if;
   end process p_mem_addr_reg;


   -- Status register
   p_sr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ctl_clc = '1' then
            reg_sr(0) <= '0';
         end if;

         if ctl_sr_alu_wren = '1' then
            reg_sr(0) <= alu_c;
            reg_sr(1) <= alu_z;
            reg_sr(6) <= alu_v;
            reg_sr(7) <= alu_s;
         end if;

         case ctl_irq_mask_wr is
            when "01" => reg_sr(2) <= data_i(2);   -- RTI
            when "10" => reg_sr(2) <= '0';         -- CLI
            when "11" => reg_sr(2) <= '1';         -- SEI, BRK
            when others => null;
         end case;

         if rst_i = '1' then
            reg_sr <= X"00";
         end if;
      end if;
   end process p_sr;


   -----------------------
   -- Drive output signals
   -----------------------

   -- Select memory address
   addr_o <= reg_pc                           when ctl_mem_addr_sel = "0000" else
             X"00" & mem_addr_reg(7 downto 0) when ctl_mem_addr_sel = "0001" else
             X"01" & reg_sp       when ctl_mem_addr_sel = "0010" else
             mem_addr_reg         when ctl_mem_addr_sel = "0011" else
             X"FFFE"              when ctl_mem_addr_sel = "1000" else    -- BRK
             X"FFFF"              when ctl_mem_addr_sel = "1001" else    -- BRK
             X"FFFA"              when ctl_mem_addr_sel = "1010" else    -- NMI
             X"FFFB"              when ctl_mem_addr_sel = "1011" else    -- NMI
             X"FFFC"              when ctl_mem_addr_sel = "1100" else    -- RESET
             X"FFFD"              when ctl_mem_addr_sel = "1101" else    -- RESET
             X"FFFE"              when ctl_mem_addr_sel = "1110" else    -- IRQ
             X"FFFF"              when ctl_mem_addr_sel = "1111" else    -- IRQ
             (others => 'X');

   -- Select memory data
   data_o <= regs_rd_data        when ctl_mem_data_sel = "00" else
             reg_pc(15 downto 8) when ctl_mem_data_sel = "01" else
             reg_pc(7 downto 0)  when ctl_mem_data_sel = "10" else
             reg_sr              when ctl_mem_data_sel = "11" else
             (others => 'X');

   rden_o <= ctl_mem_rden;
   wren_o <= ctl_mem_wren;

   -- Debug output
   debug_o(23 downto  0) <= regs_debug;
   debug_o(31 downto 24) <= reg_sp;
   debug_o(47 downto 32) <= reg_pc;
   debug_o(58 downto 48) <= ctl_debug;
   debug_o(59) <= reg_sr(2);
   debug_o(63 downto 60) <= (others => '0');

end Structural;

