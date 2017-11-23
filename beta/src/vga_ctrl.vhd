----------------------------------------------------------------------------------
-- Description:  This generates the horizontal and vertical synchronization signals
--               for a VGA display with 1280 * 1024 @ 60 Hz refresh rate.
--               User must supply a 108 MHz clock on the input.
--               This is because 1688 * 1066 * 60 Hz = 107,96 MHz.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity vga_ctrl is
   port (
      vga_clk_i : in std_logic;   -- This must be 108 MHz

      hs_o      : out std_logic;
      vs_o      : out std_logic;
      hcount_o  : out std_logic_vector(10 downto 0);
      vcount_o  : out std_logic_vector(10 downto 0);
      blank_o   : out std_logic
   );
end vga_ctrl;

architecture Behavioral of vga_ctrl is

   constant FRAME_WIDTH  : natural := 1280;
   constant FRAME_HEIGHT : natural := 1024;

   constant H_FP  : natural := 48;              -- H front porch width (pixels)
   constant H_PW  : natural := 112;             -- H sync pulse width (pixels)
   constant H_MAX : natural := 1688;            -- H total period (pixels)

   constant V_FP  : natural := 1;               -- V front porch width (lines)
   constant V_PW  : natural := 3;               -- V sync pulse width (lines)
   constant V_MAX : natural := 1066;            -- V total period (lines)

   -- The active signal is used to signal the active region of the screen (when not blank)
   signal active     : std_logic := '0';
   signal active_dly : std_logic := '0';

   -- Horizontal and Vertical counters
   signal h_cntr_reg : std_logic_vector(10 downto 0) := (others =>'0');
   signal v_cntr_reg : std_logic_vector(10 downto 0) := (others =>'0');

   -- Pipe Horizontal and Vertical Counters
   signal h_cntr_reg_dly : std_logic_vector(10 downto 0) := (others => '0');
   signal v_cntr_reg_dly : std_logic_vector(10 downto 0) := (others => '0');

   -- Horizontal and Vertical Sync
   signal h_sync_reg : std_logic := '0';
   signal v_sync_reg : std_logic := '0';

   -- Pipe Horizontal and Vertical Sync
   signal h_sync_reg_dly : std_logic := '0';
   signal v_sync_reg_dly : std_logic := '0';

begin

   -- Horizontal counter
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if h_cntr_reg = (H_MAX - 1) then
            h_cntr_reg <= (others =>'0');
         else
            h_cntr_reg <= h_cntr_reg + 1;
         end if;
      end if;
   end process;

   -- Vertical counter
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if (h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1)) then
            v_cntr_reg <= (others =>'0');
         elsif h_cntr_reg = (H_MAX - 1) then
            v_cntr_reg <= v_cntr_reg + 1;
         end if;
      end if;
   end process;

   -- Horizontal sync
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if h_cntr_reg >= (H_FP + FRAME_WIDTH - 1) and h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1) then
            h_sync_reg <= '1';
         else
            h_sync_reg <= '0';
         end if;
      end if;
   end process;

   -- Vertical sync
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1) and v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1) then
            v_sync_reg <= '1';
         else
            v_sync_reg <= '0';
         end if;
      end if;
   end process;

   -- active signal
   active <= '1' when h_cntr_reg < FRAME_WIDTH and v_cntr_reg < FRAME_HEIGHT
             else '0';

   -- Register Outputs
   process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         h_sync_reg_dly <= h_sync_reg;
         v_sync_reg_dly <= v_sync_reg;
         h_cntr_reg_dly <= h_cntr_reg;
         v_cntr_reg_dly <= v_cntr_reg;
         active_dly     <= active;
      end if;
   end process;

   -- Assign outputs
   hs_o     <= h_sync_reg_dly;
   vs_o     <= v_sync_reg_dly;
   hcount_o <= h_cntr_reg_dly;
   vcount_o <= v_cntr_reg_dly;
   blank_o  <= not active_dly;

end Behavioral;

