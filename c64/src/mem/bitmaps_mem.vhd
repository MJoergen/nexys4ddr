-----------------------------------------------------------------------------
-- Description:  This infers a BRAM to contain 16x16 bitmaps for 4 sprites.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;

entity bitmaps_mem is
   generic (
      G_NEXYS4DDR : boolean
   );
   port (
      vga_clk_i   : in  std_logic;

      cpu_clk_i   : in  std_logic;

      -- Read port @ vga_clk_i
      vga_addr_i  : in  std_logic_vector( 5 downto 0);   -- 2 bits for sprite #, and 4 bits for row.
      vga_data_o  : out std_logic_vector(15 downto 0);

      -- Write port @ cpu_clk_i
      cpu_addr_i  : in  std_logic_vector( 6 downto 0);   -- 2 bits for sprite #, 4 bits for row, and 1 bit for left/right side.
      cpu_wren_i  : in  std_logic;
      cpu_data_i  : in  std_logic_vector( 7 downto 0);
      --
      cpu_rden_i  : in  std_logic;
      cpu_data_o  : out std_logic_vector( 7 downto 0)
   );
end bitmaps_mem;

architecture Behavioral of bitmaps_mem is

   function reverse(arg : std_logic_vector) return std_logic_vector is
      variable res : std_logic_vector(arg'length-1 downto 0);
   begin
      for i in 0 to arg'length-1 loop
         res(i) := arg(arg'length-1-i);
      end loop;
      return res;
   end function reverse;

   signal cpu_data_hi : std_logic_vector(7 downto 0);
   signal cpu_data_lo : std_logic_vector(7 downto 0);

   signal vga_data_hi : std_logic_vector(7 downto 0);
   signal vga_data_lo : std_logic_vector(7 downto 0);

   signal cpu_wren_hi : std_logic;
   signal cpu_wren_lo : std_logic;

begin

   cpu_wren_hi <= '1' when (cpu_addr_i(0) = '1') and cpu_wren_i = '1' else '0';
   cpu_wren_lo <= '1' when (cpu_addr_i(0) = '0') and cpu_wren_i = '1' else '0';

   inst_mem_hi : entity work.mem
   generic map (
                  G_NEXYS4DDR => G_NEXYS4DDR,
                  G_ADDR_SIZE => 6,
                  G_DATA_SIZE => 8
               )
   port map (
      -- Port A @ cpu_clk_i
      a_clk_i     => cpu_clk_i,
      a_addr_i    => cpu_addr_i(6 downto 1),
      a_wr_en_i   => cpu_wren_hi,
      a_wr_data_i => cpu_data_i,
      a_rd_en_i   => cpu_rden_i,
      a_rd_data_o => cpu_data_hi,

      -- Port B @ vga_clk_i
      b_clk_i     => vga_clk_i,
      b_addr_i    => vga_addr_i,
      b_rd_en_i   => '1',
      b_rd_data_o => vga_data_hi
   );

   inst_mem_lo : entity work.mem
   generic map (
                  G_NEXYS4DDR => G_NEXYS4DDR,
                  G_ADDR_SIZE => 6,
                  G_DATA_SIZE => 8
               )
   port map (
      -- Port A @ cpu_clk_i
      a_clk_i     => cpu_clk_i,
      a_addr_i    => cpu_addr_i(6 downto 1),
      a_wr_en_i   => cpu_wren_lo,
      a_wr_data_i => cpu_data_i,
      a_rd_en_i   => cpu_rden_i,
      a_rd_data_o => cpu_data_lo,

      -- Port B @ vga_clk_i
      b_clk_i     => vga_clk_i,
      b_addr_i    => vga_addr_i,
      b_rd_en_i   => '1',
      b_rd_data_o => vga_data_lo
   );

   vga_data_o <= reverse(vga_data_hi) & reverse(vga_data_lo);


   cpu_data_o <= cpu_data_hi when cpu_addr_i(0) = '1' else
                 cpu_data_lo;

end Behavioral;

