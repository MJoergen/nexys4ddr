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

   signal addr  : std_logic_vector(15 downto 0);
   signal rden  : std_logic;
   signal wren  : std_logic;
   signal data  : std_logic_vector(7 downto 0);

   -- Signals connected to ALU
   signal alu_a    : std_logic_vector(7 downto 0);
   signal alu_b    : std_logic_vector(7 downto 0);
   signal alu_c    : std_logic;
   signal alu_func : std_logic_vector(3 downto 0);
   signal alu_out  : std_logic_vector(7 downto 0);
   signal alu_sr   : std_logic_vector(7 downto 0);

   -- Signals driven by the Control Logic
   signal ctl : std_logic_vector(10 downto 0);

   -- Program Registers
   signal reg_sp : std_logic_vector( 7 downto 0);
   signal reg_pc : std_logic_vector(15 downto 0);
   signal reg_sr : std_logic_vector( 7 downto 0);

   -- Signals connected to the register file
   signal reg_nr       : std_logic_vector(1 downto 0);
   signal regs_rd_data : std_logic_vector(7 downto 0);
   signal regs_wren    : std_logic;
   signal regs_wr_data : std_logic_vector(7 downto 0);
   signal regs_debug   : std_logic_vector(23 downto 0);

   -- Additional Registers
   signal inst : std_logic_vector(7 downto 0);

   -- Control signals
   signal regs_wrmux : std_logic_vector(1 downto 0);
   signal j_ena      : std_logic;
   signal j_addr     : std_logic_vector(15 downto 0);

begin
 
   -- Debug output
   debug_o(23 downto  0) <= regs_debug;
   debug_o(31 downto 24) <= reg_sp;
   debug_o(47 downto 32) <= reg_pc;
   debug_o(58 downto 48) <= ctl;
   debug_o(63 downto 59) <= (others => '0');

   -- Control signals
   rden       <= ctl(0);           -- Read data from memory or I/O
   wren       <= ctl(1);           -- Write data to memory or I/O
   alu_func   <= ctl(5 downto 2);  -- ALU function code
   regs_wren  <= ctl(6);           -- Write to register
   regs_wrmux <= ctl(8 downto 7);  -- Mux input to register file
   reg_nr     <= ctl(10 downto 9); -- Register number


   -- Internal checking
   assert rden /= '1' or wren /= '1'
      report "Simultaneous read and write"
      severity failure;

   -- Memory address is typicall the program counter
   addr <= reg_pc;

   -- First operand to ALU is typically a register
   alu_a <= regs_rd_data;

   -- Second operand to ALU is typically memory input
   alu_b <= data_i;

   -- The ALU output is typically written to memory
   data_o <= alu_out;

   -- Input to the register file is typically from memory.
   regs_wr_data <= data_i;

   -- Instantiate the ALU (combinatorial)
   inst_alu : entity work.alu
   port map (
               a_i    => alu_a,
               b_i    => alu_b,
               c_i    => alu_c,
               func_i => alu_func,
               res_o  => alu_out,
               sr_o   => alu_sr
            );

   -- Instantiate the control logic
   inst_ctl : entity work.ctl
   port map (
               clk_i  => clk_i,
               rst_i  => rst_i,
               data_i => data_i,
               ctl_o  => ctl
            );

   -- Instantiate register file
   inst_regs : entity work.regs
   port map ( 
               clk_i    => clk_i,
               rst_i    => rst_i,
               reg_nr_i => reg_nr,
               data_o   => regs_rd_data,
               wren_i   => regs_wren,
               data_i   => regs_wr_data,
               debug_o  => regs_debug
            );

   -- Instantiate Program Counter
   inst_pc : entity work.pc
   port map (
               clk_i    => clk_i,
               rst_i    => rst_i,
               pc_o     => reg_pc,
               j_ena_i  => j_ena,
               j_addr_i => j_addr
            );

   -- Drive output signals
   addr_o <= addr;
   rden_o <= rden;
   wren_o <= wren;
   data_o <= data;

end Structural;

