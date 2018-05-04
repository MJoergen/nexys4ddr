library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity comp is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end comp;

architecture Structural of comp is

   -- Clock divider for VGA
   signal vga_cnt : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk : std_logic;

   -- CPU pause (wait)
   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal cpu_cnt  : std_logic_vector(24 downto 0) := (others => '0');
   signal cpu_wait : std_logic;

   -- VGA signals
   signal vga_hs   : std_logic;
   signal vga_vs   : std_logic;
   signal vga_col  : std_logic_vector(7 downto 0);
   signal digits   : std_logic_vector(23 downto 0);

   -- CPU signals
   signal cpu_addr : std_logic_vector(15 downto 0);
   signal cpu_data : std_logic_vector(7 downto 0);
   signal mem_data : std_logic_vector(7 downto 0);
   signal cpu_wren : std_logic;

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_cnt <= vga_cnt + 1;
      end if;
   end process;

   vga_clk <= vga_cnt(1);

   
   --------------------------------------------------
   -- Generate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   port map (
      clk_i    => vga_clk,
      digits_i => digits,
      hs_o     => vga_hs,
      vs_o     => vga_vs,
      col_o    => vga_col
   );


   --------------------------------------------------
   -- Generate data to be shown on VGA
   --------------------------------------------------

   digits(23 downto 8) <= cpu_addr;
   digits( 7 downto 0) <= mem_data;


   --------------------------------------------------
   -- Generate CPU wait signal
   --------------------------------------------------

   process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         cpu_cnt <= cpu_cnt + sw_i + 1;
      end if;
   end process;

   cpu_wait <= '0' when (cpu_cnt + sw_i + 1) < cpu_cnt else '1';

   
   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   generic map (
      G_ADDR_BITS => 4  -- 16 bytes
   )
   port map (
      clk_i  => vga_clk,
      addr_i => cpu_addr(3 downto 0),
      wren_i => cpu_wren,
      data_i => cpu_data,
      data_o => mem_data
   );


   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   i_cpu : entity work.cpu
   port map (
      clk_i  => vga_clk,
      wait_i => cpu_wait,
      addr_o => cpu_addr,
      wren_o => cpu_wren,
      data_o => cpu_data,
      data_i => mem_data
   );


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

