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

   -- Clock enable for CPU
   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal cpu_cnt : std_logic_vector(24 downto 0) := (others => '0');
   signal ce : std_logic;

   -- VGA signals
   signal vga_hs    : std_logic;
   signal vga_vs    : std_logic;
   signal vga_col   : std_logic_vector(7 downto 0);
   signal digits    : std_logic_vector(23 downto 0);

   -- CPU signals
   signal addr     : std_logic_vector(15 downto 0);
   signal data_cpu : std_logic_vector(7 downto 0);
   signal data_mem : std_logic_vector(7 downto 0);
   signal wren     : std_logic;

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
   -- Divide VGA clock down.
   --------------------------------------------------

   process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         cpu_cnt <= cpu_cnt + sw_i + 1;
      end if;
   end process;

   ce <= '1' when (cpu_cnt + sw_i + 1) < cpu_cnt else '0';

   
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


   digits(15 downto 0)  <= addr;
   digits(23 downto 16) <= data_mem;

   --------------------------------------------------
   -- Instantiate memory
   --------------------------------------------------
   
   i_mem : entity work.mem
   generic map (
      G_ADDR_BITS => 11    -- 2 kBytes
   )
   port map (
      clk_i  => vga_clk,
      addr_i => addr(10 downto 0),
      wren_i => wren,
      data_i => data_cpu,
      data_o => data_mem
   );


   --------------------------------------------------
   -- Instantiate CPU
   --------------------------------------------------
   
   i_cpu : entity work.cpu
   port map (
      clk_i  => vga_clk,
      ce_i   => ce,
      addr_o => addr,
      wren_o => wren,
      data_o => data_cpu,
      data_i => data_mem
   );


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

