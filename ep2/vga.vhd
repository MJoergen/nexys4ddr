library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

entity vga is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
   );
end vga;

architecture Structural of vga is

   -- Define constants used for 640x480 @ 60 Hz.
   -- Requires a clock of approx 25.175 MHz.
   constant SIZE_X   : integer := 640;
   constant HS_FIRST : integer := 655;
   constant HS_LAST  : integer := 750;
   constant COUNT_X  : integer := 800;
   constant SIZE_Y   : integer := 480;
   constant VS_FIRST : integer := 489;
   constant VS_LAST  : integer := 490;
   constant COUNT_Y  : integer := 525;

   signal pix_x : std_logic_vector(9 downto 0);
   signal pix_y : std_logic_vector(9 downto 0);

   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;
   signal vga_col : std_logic_vector(7 downto 0);

   signal vga_clk : std_logic;

   signal clk_fbin  : std_logic;
   signal clk_fbout : std_logic;
   signal clk_out0  : std_logic;

   constant zero : std_logic_vector(63 downto 0) :=
      "01110000" &
      "10001000" &
      "10001000" &
      "10001000" &
      "10001000" &
      "10001000" &
      "01110000" &
      "00000000";

   constant one : std_logic_vector(63 downto 0) :=
      "00010000" &
      "00110000" &
      "01010000" &
      "00010000" &
      "00010000" &
      "00010000" &
      "01111000" &
      "00000000";

   signal row : integer range 0 to 7;
   signal col : integer range 0 to 7;
   signal char_x : std_logic_vector(5 downto 0);
   signal char_y : std_logic_vector(5 downto 0);

begin

   -- Instantiation of the MMCM PRIMITIVE
   -- Generated clock will have frequency 10.125/40.25*100 MHz = 25.16 MHz
   inst_mmcme2_adv : MMCME2_ADV
   generic map (
      CLKFBOUT_MULT_F      => 10.125,  -- Must be multiple of 0.125
      CLKOUT0_DIVIDE_F     => 40.25,   -- Must be multiple of 0.125
      CLKIN1_PERIOD        => 10.0)    -- 10 ns = 100 MHz.
   port map (
      -- Input clock control
      CLKFBIN             => clk_fbin,
      CLKIN1              => clk_i,
      -- Output clocks
      CLKFBOUT            => clk_fbout,
      CLKOUT0             => clk_out0,
      -- The rest are unused
      CLKIN2              => '0',
      CLKINSEL            => '1',
      DADDR               => (others => '0'),
      DCLK                => '0',
      DEN                 => '0',
      DI                  => (others => '0'),
      DWE                 => '0',
      PSCLK               => '0',
      PSEN                => '0',
      PSINCDEC            => '0',
      PWRDWN              => '0',
      RST                 => '0');

   inst_clk_fbout_buf : BUFG
   port map (
      I => clk_fbout,
      O => clk_fbin);
 
   inst_clk_out0_buf : BUFG
   port map (
      I => clk_out0,
      O => vga_clk);


   p_pix_x : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if pix_x = COUNT_X-1 then
            pix_x <= (others => '0');
         else
            pix_x <= pix_x + 1;
         end if;
      end if;
   end process p_pix_x;

   p_pix_y : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         if pix_x = COUNT_X-1  then
            if pix_y = COUNT_Y-1 then
               pix_y <= (others => '0');
            else
               pix_y <= pix_y + 1;
            end if;
         end if;
      end if;
   end process p_pix_y;

   p_hs : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_hs <= '0';
         if pix_x >= HS_FIRST and pix_x <= HS_LAST then
            vga_hs <= '1';
         end if;
      end if;
   end process p_hs;

   p_vs : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_vs <= '0';
         if pix_y >= VS_FIRST and pix_y <= VS_LAST then
            vga_vs <= '1';
         end if;
      end if;
   end process p_vs;

   char_x <= pix_x(9 downto 4);
   char_y <= pix_y(9 downto 4);
   col    <= 7 - conv_integer(pix_x(3 downto 1));
   row    <= 7 - conv_integer(pix_y(3 downto 1));

   p_col : process (vga_clk)
      variable digit_v  : std_logic;
      variable offset_v : integer;
      variable pix_v    : std_logic;
   begin
      if rising_edge(vga_clk) then
         vga_col <= (others => '0');

         if char_y = 15 and char_x >= 20 and char_x < 28 then
            offset_v := conv_integer(char_x)-20;
            digit_v := sw_i(7-offset_v);

            if digit_v = '1' then
               pix_v := one(row*8+col);
            else
               pix_v := zero(row*8+col);
            end if;

            if pix_v = '1' then
               vga_col <= (others => '1');
            end if;
         end if;
      end if;
   end process p_col;

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= vga_col;

end architecture Structural;

