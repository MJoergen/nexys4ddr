library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- In this version the design can display 24 binary digits on the VGA output.
-- The first 16 bits show the value of the address bus connected to the
-- internal memory.  The last 8 bits show the value read from the memory.
--
-- The address bus increments automatically. The speed is controlled by the
-- slide switches.

entity comp is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture structural of comp is

   -- Clock divider for VGA
   signal vga_cnt  : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk  : std_logic;

   -- Memory signals
   signal mem_wait : std_logic;

   -- Input to VGA block
   signal digits   : std_logic_vector(23 downto 0);

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   vga_cnt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_cnt <= vga_cnt + 1;
      end if;
   end process vga_cnt_proc;

   vga_clk <= vga_cnt(1);

   
   --------------------------------------------------
   -- Generate wait signal
   --------------------------------------------------

   waiter_inst : entity work.waiter
   port map (
      clk_i  => vga_clk,
      inc_i  => sw_i,
      wait_o => mem_wait
   ); -- waiter_inst


   --------------------------------------------------
   -- Instantiate MAIN module
   --------------------------------------------------
   
   main_inst : entity work.main
   port map (
      clk_i    => vga_clk,
      wait_i   => mem_wait,
      digits_o => digits
   ); -- main_inst

   
   --------------------------------------------------
   -- Generate VGA module
   --------------------------------------------------

   vga_inst : entity work.vga
   port map (
      clk_i     => vga_clk,
      digits_i  => digits,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o
   ); -- vga_inst

end architecture structural;

