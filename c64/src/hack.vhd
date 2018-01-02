library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity hack is

   generic (
      G_CHAR_FILE : string := "charset1.bin.txt"
   );
   port (
      -- Clock
      clk_i     : in  std_logic;  -- 100 MHz

      -- Reset
      rstn_i    : in  std_logic;  -- Asserted low

      -- Input switches and push buttons
      sw_i      : in  std_logic_vector (15 downto 0);
      btn_i     : in  std_logic_vector ( 4 downto 0);

     -- Output to VGA monitor
      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)
  );

end hack;

architecture Structural of hack is

   signal clk_vga : std_logic;
   signal rst_vga : std_logic := '1';  -- Asserted high.
   
   signal cpu_addr   : std_logic_vector(8 downto 0);
   signal cpu_cs_vga : std_logic;
   signal vga_data   : std_logic_vector(7 downto 0);
   signal cpu_wren   : std_logic;
   signal cpu_data   : std_logic_vector(7 downto 0);

   signal counter : integer := 0;

begin

   p_config : process (clk_vga)

      type t_config is record
         addr : std_logic_vector(8 downto 0);
         data : std_logic_vector(7 downto 0);
      end record t_config;

      type t_config_vector is array (natural range <>) of t_config;

      constant C_CONFIG : t_config_vector := (
         -- Sprite 0
         ("0" & X"00", X"A5"),
         ("0" & X"01", X"0F"),
         ("0" & X"02", X"3C"),
         ("1" & X"00", X"20"),   -- X position bits 7-0
         ("1" & X"01", X"00"),   -- X position MSB
         ("1" & X"02", X"00"),   -- Y position
         ("1" & X"03", X"FF"),   -- Color
         ("1" & X"04", X"01"),   -- Enable
         ("1" & X"05", X"00")    -- Behind
      );

   begin
      if rising_edge(clk_vga) then
         cpu_wren   <= '0';
         cpu_cs_vga <= '0';

         if counter < C_CONFIG'length then
            cpu_addr <= C_CONFIG(counter).addr;
            cpu_data <= C_CONFIG(counter).data;
            cpu_wren <= '1';
            cpu_cs_vga <= '1';
            counter <= counter + 1;
         end if;

         if rst_vga = '1' then
            counter <= 0;
         end if;
      end if;
   end process p_config;


   -- Generate VGA clock
   inst_clk_wiz_vga : entity work.clk_wiz_vga
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => clk_vga  -- 25 MHz
   );

   -- Generate reset synchronous to VGA clock.
   p_rst_vga : process (clk_vga)
   begin
      if rising_edge(clk_vga) then
         rst_vga <= not rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_rst_vga;


   -- Instantiate VGA module
   inst_vga_module : entity work.vga_module
   generic map (
                  G_CHAR_FILE => G_CHAR_FILE 
               )
   port map (
      clk_i => clk_vga,
      rst_i => rst_vga,
      hs_o  => vga_hs_o,
      vs_o  => vga_vs_o,
      col_o => vga_col_o,

      -- Configuration
      addr_i => cpu_addr,
      cs_i   => cpu_cs_vga,
      data_o => vga_data,
      wren_i => cpu_wren,
      data_i => cpu_data
   );

end Structural;

