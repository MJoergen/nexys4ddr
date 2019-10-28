library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the VERA.
-- It generates a display with 640x480 pixels at 60 Hz refresh rate.

entity vera is
   port (
      clk_i     : in    std_logic;                       -- 25 MHz

      vga_hs_o  : out   std_logic;                       -- VGA
      vga_vs_o  : out   std_logic;
      vga_col_o : out   std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end vera;

architecture structural of vera is

   signal wr_addr_s   : std_logic_vector(16 downto 0);
   signal wr_en_s     : std_logic;
   signal wr_data_s   : std_logic_vector( 7 downto 0);
   signal mapbase_s   : std_logic_vector(16 downto 0);
   signal tilebase_s  : std_logic_vector(16 downto 0);

   signal vaddr_s     : std_logic_vector(16 downto 0);
   signal vread_s     : std_logic;
   signal vdata_s     : std_logic_vector( 7 downto 0);

   signal pix_x_s     : std_logic_vector(9 downto 0);
   signal pix_y_s     : std_logic_vector(9 downto 0);

   signal paddr_s     : std_logic_vector( 7 downto 0);
   signal pdata_s     : std_logic_vector(11 downto 0);
   signal pix_x_out_s : std_logic_vector( 9 downto 0);
   signal pix_y_out_s : std_logic_vector( 9 downto 0);
   signal col_out_s   : std_logic_vector(11 downto 0);


   -- This defines a type containing an array of bytes
   type wr_record is record
      addr : std_logic_vector(11 downto 0);
      data : std_logic_vector( 7 downto 0);
   end record wr_record;
   type wr_record_vector is array (natural range <>) of wr_record;

   constant wr_default : wr_record_vector := (
      (X"000", X"5F"),
      (X"001", X"64"),
      (X"002", X"A0"),
      (X"003", X"64"),
      (X"004", X"A0"),
      (X"005", X"64"),
      (X"006", X"DF"),
      (X"007", X"64"),
      (X"008", X"20"),
      (X"009", X"64"),
      (X"00A", X"20"),
      (X"00B", X"64"),
      (X"00C", X"20"),
      (X"00D", X"64"),
      (X"00E", X"E9"),
      (X"00F", X"64"),
      (X"010", X"A0"),
      (X"011", X"64"),
      (X"012", X"A0"),
      (X"013", X"64"),
      (X"014", X"69"),
      (X"015", X"64"),
      (X"100", X"20"),
      (X"101", X"6E"),
      (X"102", X"5F"),
      (X"103", X"6E"),
      (X"104", X"A0"),
      (X"105", X"6E"),
      (X"106", X"A0"),
      (X"107", X"6E"),
      (X"108", X"DF"),
      (X"109", X"6E"),
      (X"10A", X"20"),
      (X"10B", X"6E"),
      (X"10C", X"E9"),
      (X"10D", X"6E"),
      (X"10E", X"A0"),
      (X"10F", X"6E"),
      (X"110", X"A0"),
      (X"111", X"6E"),
      (X"112", X"69"),
      (X"113", X"6E"),
      (X"114", X"20"),
      (X"115", X"61"),
      (X"116", X"20"),
      (X"117", X"61"),
      (X"118", X"2A"),
      (X"119", X"61"),
      (X"11A", X"2A"),
      (X"11B", X"61"),
      (X"11C", X"2A"),
      (X"11D", X"61"),
      (X"11E", X"2A"),
      (X"11F", X"61"),
      (X"120", X"20"),
      (X"121", X"61"),
      (X"122", X"03"),
      (X"123", X"61"),
      (X"124", X"0F"),
      (X"125", X"61"),
      (X"126", X"0D"),
      (X"127", X"61"),
      (X"128", X"0D"),
      (X"129", X"61"),
      (X"12A", X"01"),
      (X"12B", X"61"),
      (X"12C", X"0E"),
      (X"12D", X"61"),
      (X"12E", X"04"),
      (X"12F", X"61"),
      (X"130", X"05"),
      (X"131", X"61"),
      (X"132", X"12"),
      (X"133", X"61"),
      (X"134", X"20"),
      (X"135", X"61"),
      (X"136", X"18"),
      (X"137", X"61"),
      (X"138", X"31"),
      (X"139", X"61"),
      (X"13A", X"36"),
      (X"13B", X"61"),
      (X"13C", X"20"),
      (X"13D", X"61"),
      (X"13E", X"02"),
      (X"13F", X"61"),
      (X"140", X"01"),
      (X"141", X"61"),
      (X"142", X"13"),
      (X"143", X"61"),
      (X"144", X"09"),
      (X"145", X"61"),
      (X"146", X"03"),
      (X"147", X"61"),
      (X"148", X"20"),
      (X"149", X"61"),
      (X"14A", X"16"),
      (X"14B", X"61"),
      (X"14C", X"32"),
      (X"14D", X"61"),
      (X"14E", X"20"),
      (X"14F", X"61"),
      (X"150", X"2A"),
      (X"151", X"61"),
      (X"152", X"2A"),
      (X"153", X"61"),
      (X"154", X"2A"),
      (X"155", X"61"),
      (X"156", X"2A"),
      (X"157", X"61"),
      (X"200", X"20"),
      (X"201", X"63"),
      (X"202", X"20"),
      (X"203", X"63"),
      (X"204", X"5F"),
      (X"205", X"63"),
      (X"206", X"A0"),
      (X"207", X"63"),
      (X"208", X"A0"),
      (X"209", X"63"),
      (X"20A", X"20"),
      (X"20B", X"63"),
      (X"20C", X"A0"),
      (X"20D", X"63"),
      (X"20E", X"A0"),
      (X"20F", X"63"),
      (X"210", X"69"),
      (X"211", X"63"),
      (X"300", X"20"),
      (X"301", X"65"),
      (X"302", X"20"),
      (X"303", X"65"),
      (X"304", X"20"),
      (X"305", X"65"),
      (X"306", X"20"),
      (X"307", X"65"),
      (X"308", X"A0"),
      (X"309", X"65"),
      (X"30A", X"20"),
      (X"30B", X"65"),
      (X"30C", X"A0"),
      (X"30D", X"65"),
      (X"30E", X"20"),
      (X"30F", X"61"),
      (X"310", X"20"),
      (X"311", X"61"),
      (X"312", X"20"),
      (X"313", X"61"),
      (X"314", X"20"),
      (X"315", X"61"),
      (X"316", X"20"),
      (X"317", X"61"),
      (X"318", X"35"),
      (X"319", X"61"),
      (X"31A", X"31"),
      (X"31B", X"61"),
      (X"31C", X"32"),
      (X"31D", X"61"),
      (X"31E", X"0B"),
      (X"31F", X"61"),
      (X"320", X"20"),
      (X"321", X"61"),
      (X"322", X"08"),
      (X"323", X"61"),
      (X"324", X"09"),
      (X"325", X"61"),
      (X"326", X"07"),
      (X"327", X"61"),
      (X"328", X"08"),
      (X"329", X"61"),
      (X"32A", X"20"),
      (X"32B", X"61"),
      (X"32C", X"12"),
      (X"32D", X"61"),
      (X"32E", X"01"),
      (X"32F", X"61"),
      (X"330", X"0D"),
      (X"331", X"61"),
      (X"400", X"20"),
      (X"401", X"67"),
      (X"402", X"20"),
      (X"403", X"67"),
      (X"404", X"E9"),
      (X"405", X"67"),
      (X"406", X"A0"),
      (X"407", X"67"),
      (X"408", X"A0"),
      (X"409", X"67"),
      (X"40A", X"20"),
      (X"40B", X"67"),
      (X"40C", X"A0"),
      (X"40D", X"67"),
      (X"40E", X"A0"),
      (X"40F", X"67"),
      (X"410", X"DF"),
      (X"411", X"67"),
      (X"500", X"20"),
      (X"501", X"68"),
      (X"502", X"E9"),
      (X"503", X"68"),
      (X"504", X"A0"),
      (X"505", X"68"),
      (X"506", X"A0"),
      (X"507", X"68"),
      (X"508", X"69"),
      (X"509", X"68"),
      (X"50A", X"20"),
      (X"50B", X"68"),
      (X"50C", X"5F"),
      (X"50D", X"68"),
      (X"50E", X"A0"),
      (X"50F", X"68"),
      (X"510", X"A0"),
      (X"511", X"68"),
      (X"512", X"DF"),
      (X"513", X"68"),
      (X"514", X"20"),
      (X"515", X"61"),
      (X"516", X"20"),
      (X"517", X"61"),
      (X"518", X"33"),
      (X"519", X"61"),
      (X"51A", X"38"),
      (X"51B", X"61"),
      (X"51C", X"36"),
      (X"51D", X"61"),
      (X"51E", X"35"),
      (X"51F", X"61"),
      (X"520", X"35"),
      (X"521", X"61"),
      (X"522", X"20"),
      (X"523", X"61"),
      (X"524", X"02"),
      (X"525", X"61"),
      (X"526", X"01"),
      (X"527", X"61"),
      (X"528", X"13"),
      (X"529", X"61"),
      (X"52A", X"09"),
      (X"52B", X"61"),
      (X"52C", X"03"),
      (X"52D", X"61"),
      (X"52E", X"20"),
      (X"52F", X"61"),
      (X"530", X"02"),
      (X"531", X"61"),
      (X"532", X"19"),
      (X"533", X"61"),
      (X"534", X"14"),
      (X"535", X"61"),
      (X"536", X"05"),
      (X"537", X"61"),
      (X"538", X"13"),
      (X"539", X"61"),
      (X"53A", X"20"),
      (X"53B", X"61"),
      (X"53C", X"06"),
      (X"53D", X"61"),
      (X"53E", X"12"),
      (X"53F", X"61"),
      (X"540", X"05"),
      (X"541", X"61"),
      (X"542", X"05"),
      (X"543", X"61"),
      (X"600", X"E9"),
      (X"601", X"62"),
      (X"602", X"A0"),
      (X"603", X"62"),
      (X"604", X"A0"),
      (X"605", X"62"),
      (X"606", X"69"),
      (X"607", X"62"),
      (X"608", X"20"),
      (X"609", X"62"),
      (X"60A", X"20"),
      (X"60B", X"62"),
      (X"60C", X"20"),
      (X"60D", X"62"),
      (X"60E", X"5F"),
      (X"60F", X"62"),
      (X"610", X"A0"),
      (X"611", X"62"),
      (X"612", X"A0"),
      (X"613", X"62"),
      (X"614", X"DF"),
      (X"615", X"62"),
      (X"800", X"12"),
      (X"801", X"61"),
      (X"802", X"05"),
      (X"803", X"61"),
      (X"804", X"01"),
      (X"805", X"61"),
      (X"806", X"04"),
      (X"807", X"61"),
      (X"808", X"19"),
      (X"809", X"61"),
      (X"80A", X"2E"),
      (X"80B", X"61"));

  signal wr_index : integer := 0;

begin

   -- TBD
   mapbase_s  <= (others => '0');
   tilebase_s <= (others => '0');

   -- This is a temporary process that populates the VRAM
   p_write_vram : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wr_en_s <= '0';
         if wr_index < wr_default'length then
            wr_addr_s <= "00000" & wr_default(wr_index).addr;
            wr_en_s   <= '1';
            wr_data_s <= wr_default(wr_index).data;
            wr_index  <= wr_index + 1;
         end if;
      end if;
   end process p_write_vram;


   -------------------------
   -- Instantiate Video RAM
   -------------------------

   i_vram : entity work.vram
      port map (
         clk_i     => clk_i,
         wr_addr_i => wr_addr_s,
         wr_en_i   => wr_en_s,
         wr_data_i => wr_data_s,
         rd_addr_i => vaddr_s,
         rd_en_i   => vread_s,
         rd_data_o => vdata_s
      ); -- i_vram


   ---------------------------
   -- Instantiate palette RAM
   ---------------------------

   i_palette : entity work.palette
      port map (
         clk_i  => clk_i,
         addr_i => paddr_s,
         data_o => pdata_s
      ); -- i_palette


   ------------------------------
   -- Instantiate pixel counters
   ------------------------------

   i_pix : entity work.pix
      generic map (
         G_PIX_X_COUNT => 800,
         G_PIX_Y_COUNT => 525
      )
      port map (
         clk_i   => clk_i,
         pix_x_o => pix_x_s,
         pix_y_o => pix_y_s
      ); -- i_pix


   -------------------------------
   -- Instantiate mode 0 renderer
   -------------------------------

   i_mode0 : entity work.mode0
      port map (
         clk_i      => clk_i,
         pix_x_i    => pix_x_s,
         pix_y_i    => pix_y_s,
         mapbase_i  => mapbase_s,
         tilebase_i => tilebase_s,
         vaddr_o    => vaddr_s,
         vread_o    => vread_s,
         vdata_i    => vdata_s,
         paddr_o    => paddr_s,
         pdata_i    => pdata_s,
         pix_x_o    => pix_x_out_s,
         pix_y_o    => pix_y_out_s,
         col_o      => col_out_s
      ); -- i_mode0


   ------------------------------
   -- Instantiate VGA signalling
   ------------------------------

   i_vga : entity work.vga
      port map (
         clk_i     => clk_i,
         pix_x_i   => pix_x_out_s,
         pix_y_i   => pix_y_out_s,
         col_i     => col_out_s,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vga

end architecture structural;

