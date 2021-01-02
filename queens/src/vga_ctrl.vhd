library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga_ctrl is
   port (
      clk_i    : in std_logic;
      rst_i    : in std_logic;

      hs_o     : out std_logic;
      vs_o     : out std_logic;
      hcount_o : out std_logic_vector(11 downto 0);
      vcount_o : out std_logic_vector(11 downto 0);
      blank_o  : out std_logic
   );
end entity vga_ctrl;

architecture synthesis of vga_ctrl is

   constant FRAME_WIDTH  : natural := 640;
   constant FRAME_HEIGHT : natural := 480;

   constant H_FP  : natural := 16;     --H front porch width (pixels)
   constant H_PW  : natural := 96;    --H sync pulse width (pixels)
   constant H_MAX : natural := 800;    --H total period (pixels)

   constant V_FP  : natural := 10;      --V front porch width (lines)
   constant V_PW  : natural := 2;      --V sync pulse width (lines)
   constant V_MAX : natural := 525;    --V total period (lines)

   constant H_POL : std_logic := '1';
   constant V_POL : std_logic := '1';

   -------------------------------------------------------------------------

   -- VGA Controller specific signals: Counters, Sync, R, G, B

   -------------------------------------------------------------------------
   -- The active signal is used to signal the active region of the screen (when not blank)
   signal active  : std_logic;
   signal active_dly  : std_logic;

   -- Horizontal and Vertical counters
   signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
   signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');

   -- Pipe Horizontal and Vertical Counters
   signal h_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');
   signal v_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');

   -- Horizontal and Vertical Sync
   signal h_sync_reg : std_logic := not(H_POL);
   signal v_sync_reg : std_logic := not(V_POL);
   -- Pipe Horizontal and Vertical Sync
   signal h_sync_reg_dly : std_logic := not(H_POL);
   signal v_sync_reg_dly : std_logic :=  not(V_POL);

begin

   ---------------------------------------------------------------
   -- Generate Horizontal, Vertical counters and the Sync signals
   ---------------------------------------------------------------

   -- Horizontal counter
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if h_cntr_reg = (H_MAX - 1) then
            h_cntr_reg <= (others =>'0');
         else
            h_cntr_reg <= h_cntr_reg + 1;
         end if;
      end if;
   end process;

   -- Vertical counter
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if (h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1)) then
            v_cntr_reg <= (others =>'0');
         elsif h_cntr_reg = (H_MAX - 1) then
            v_cntr_reg <= v_cntr_reg + 1;
         end if;
      end if;
   end process;

   -- Horizontal sync
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if h_cntr_reg >= (H_FP + FRAME_WIDTH - 1) and h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1) then
            h_sync_reg <= H_POL;
         else
            h_sync_reg <= not(H_POL);
         end if;
      end if;
   end process;

   -- Vertical sync
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1) and v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1) then
            v_sync_reg <= V_POL;
         else
            v_sync_reg <= not(V_POL);
         end if;
      end if;
   end process;

   --------------------
   -- The active
   --------------------
   -- active signal
   active <= '1' when h_cntr_reg < FRAME_WIDTH and v_cntr_reg < FRAME_HEIGHT
             else '0';

   -- Register Outputs
   process (clk_i)
   begin
      if rising_edge(clk_i) then
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

end architecture synthesis;

