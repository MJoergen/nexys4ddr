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
   signal alu_c    : std_logic;
   signal alu_out  : std_logic_vector(7 downto 0);
   signal alu_sr   : std_logic_vector(7 downto 0);

   -- Signals driven by the Control Logic
   signal ctl_mem_rden      : std_logic;    -- Read from memory
   signal ctl_mem_wren      : std_logic;    -- Write to memory
   signal ctl_mem_addr_wren : std_logic;    -- Write to address hold register
   signal ctl_mem_addr_sel  : std_logic_vector(1 downto 0);   -- Memory address select
   signal ctl_mem_data_sel  : std_logic_vector(1 downto 0);   -- Memory data select
   signal ctl_reg_data_sel  : std_logic_vector(1 downto 0);   -- Register write data select
   signal ctl_reg_wren      : std_logic;    -- Write to register file
   signal ctl_reg_nr        : std_logic_vector(1 downto 0);   -- Register number
   signal ctl_pc_sel        : std_logic_vector(1 downto 0);   -- PC select
   signal ctl_alu_func      : std_logic_vector(3 downto 0);   -- ALU function
   signal ctl_debug         : std_logic_vector(10 downto 0);

   -- Program Registers
   signal reg_sp : std_logic_vector( 7 downto 0);
   signal reg_pc : std_logic_vector(15 downto 0);
   signal reg_sr : std_logic_vector( 7 downto 0);

   -- Signals connected to the register file
   signal regs_rd_data : std_logic_vector(7 downto 0);
   signal regs_wr_data : std_logic_vector(7 downto 0);
   signal regs_debug   : std_logic_vector(23 downto 0);

   -- Additional Registers
   signal inst : std_logic_vector(7 downto 0);

   -- Control signals
   signal j_ena      : std_logic;
   signal j_addr     : std_logic_vector(15 downto 0);

   signal mem_addr_reg : std_logic_vector(7 downto 0);

begin
 
   -- Internal checking
   assert ctl_mem_rden /= '1' or ctl_mem_wren /= '1'
      report "Simultaneous read and write"
      severity failure;

   -- First operand to ALU is typically a register
   alu_a <= regs_rd_data;

   -- Second operand to ALU is typically memory input
   alu_b <= data_i;

   -- The ALU output is typically written to memory
   data_o <= alu_out;

   -- Input to the register file is typically from memory.
   regs_wr_data <= data_i when ctl_reg_data_sel = "00" else
                   alu_out when ctl_reg_data_sel = "01" else
                   (others => 'X');

   -- Instantiate the ALU (combinatorial)
   inst_alu : entity work.alu
   port map (
               a_i    => alu_a,
               b_i    => alu_b,
               c_i    => alu_c,
               func_i => ctl_alu_func,
               res_o  => alu_out,
               sr_o   => alu_sr
            );

   -- Instantiate the control logic
   inst_ctl : entity work.ctl
   port map (
               clk_i           => clk_i,
               rst_i           => rst_i,
               data_i          => data_i,
               mem_rden_o      => ctl_mem_rden,
               mem_wren_o      => ctl_mem_wren,
               mem_addr_wren_o => ctl_mem_addr_wren,
               mem_addr_sel_o  => ctl_mem_addr_sel,
               mem_data_sel_o  => ctl_mem_data_sel,
               reg_data_sel_o  => ctl_reg_data_sel,
               reg_wren_o      => ctl_reg_wren,
               reg_nr_o        => ctl_reg_nr,
               pc_sel_o        => ctl_pc_sel,
               alu_func_o      => ctl_alu_func,
               debug_o         => ctl_debug
            );

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
            when "11" => null;
            when others => assert false severity failure;
         end case;

         if rst_i = '1' then
            reg_pc <= X"FC00";
         end if;
      end if;
   end process p_pc;
      

   -- Memory address hold register
   p_mem_addr_sel : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if ctl_mem_addr_wren = '1' then
            mem_addr_reg <= data_i;
         end if;
      end if;
   end process p_mem_addr_sel;


   -----------------------
   -- Drive output signals
   -----------------------

   -- Select memory address
   addr_o <= reg_pc               when ctl_mem_addr_sel = "00" else
             X"00" & mem_addr_reg when ctl_mem_addr_sel = "01" else
             (others => 'X');

   -- Select memory data
   data_o <= regs_rd_data when ctl_mem_data_sel = "00" else
             (others => 'X');

   rden_o <= ctl_mem_rden;
   wren_o <= ctl_mem_wren;

   -- Debug output
   debug_o(23 downto  0) <= regs_debug;
   debug_o(31 downto 24) <= reg_sp;
   debug_o(47 downto 32) <= reg_pc;
   debug_o(58 downto 48) <= ctl_debug;
   debug_o(63 downto 59) <= (others => '0');

end Structural;

