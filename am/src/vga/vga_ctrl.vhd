----------------------------------------------------------------------------------
-- Description:  This generates the horizontal and vertical synchronization signals
--               for a VGA display.
-- The timing signals are described in this web page:
-- https://eewiki.net/pages/viewpage.action?pageId=15925278
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity vga_ctrl is
   port (
      rst_i    : in std_logic;
      clk_i    : in std_logic;

      hcount_o : out std_logic_vector(10 downto 0);
      vcount_o : out std_logic_vector(10 downto 0);
      hs_o     : out std_logic;
      vs_o     : out std_logic;
      blank_o  : out std_logic
   );
end vga_ctrl;

architecture Behavioral of vga_ctrl is

   -- The following numbers produce a 640x480 screen at 60 Hz refresh rate.
   -- This assumes a clock frequency of 25.175 MHz.
   constant FRAME_WIDTH  : natural := 640;
   constant FRAME_HEIGHT : natural := 480;

   constant H_FP  : natural := 16;             -- H front porch width (pixels)
   constant H_PW  : natural := 96;             -- H sync pulse width (pixels)
   constant H_MAX : natural := 800;            -- H total period (pixels)

   constant V_FP  : natural := 10;             -- V front porch width (lines)
   constant V_PW  : natural := 2;              -- V sync pulse width (lines)
   constant V_MAX : natural := 525;            -- V total period (lines)

   -- Horizontal and Vertical counters
   signal h_cntr : std_logic_vector(10 downto 0) := (others =>'0');
   signal v_cntr : std_logic_vector(10 downto 0) := (others =>'0');

   -- Horizontal and Vertical Sync
   signal h_sync : std_logic := '0';
   signal v_sync : std_logic := '0';

   -- The active signal is used to signal the active region of the screen (when not blank)
   signal active : std_logic := '0';

begin

   -- Horizontal counter
   p_h_cntr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if h_cntr = (H_MAX - 1) then
            h_cntr <= (others =>'0');
         else
            h_cntr <= h_cntr + 1;
         end if;

         if (rst_i = '1') then
            h_cntr <= (others => '0');
         end if;
      end if;
   end process p_h_cntr;

   -- Vertical counter
   p_v_cntr : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if (h_cntr = (H_MAX - 1)) and (v_cntr = (V_MAX - 1)) then
            v_cntr <= (others =>'0');
         elsif h_cntr = (H_MAX - 1) then
            v_cntr <= v_cntr + 1;
         end if;

         if (rst_i = '1') then
            v_cntr <= (others => '0');
         end if;
      end if;
   end process p_v_cntr;

   -- Horizontal sync
   p_h_sync : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if h_cntr >= (H_FP + FRAME_WIDTH - 1) and h_cntr < (H_FP + FRAME_WIDTH + H_PW - 1) then
            h_sync <= '0';
         else
            h_sync <= '1';
         end if;
      end if;
   end process p_h_sync;

   -- Vertical sync
   p_v_sync : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if v_cntr >= (V_FP + FRAME_HEIGHT - 1) and v_cntr < (V_FP + FRAME_HEIGHT + V_PW - 1) then
            v_sync <= '0';
         else
            v_sync <= '1';
         end if;
      end if;
   end process p_v_sync;

   -- active signal
   active <= '1' when h_cntr < FRAME_WIDTH and v_cntr < FRAME_HEIGHT
             else '0';

   -- Assign outputs
   hs_o     <= h_sync;
   vs_o     <= v_sync;
   hcount_o <= h_cntr;
   vcount_o <= v_cntr;
   blank_o  <= not active;

end Behavioral;

