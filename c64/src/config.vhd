library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity config is

   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      cs_o   : out std_logic;
      wren_o : out std_logic;
      addr_o : out std_logic_vector(8 downto 0);
      data_o : out std_logic_vector(7 downto 0)
   );

end entity config;

architecture Structural of config is

   signal cs   : std_logic;
   signal wren : std_logic;
   signal addr : std_logic_vector(8 downto 0);
   signal data : std_logic_vector(7 downto 0);

   signal counter : integer := 0;

begin

   p_config : process (clk_i)

      type t_config is record
         addr : std_logic_vector(8 downto 0);
         data : std_logic_vector(7 downto 0);
      end record t_config;

      type t_config_vector is array (natural range <>) of t_config;

      constant C_CONFIG : t_config_vector := (
         -- Sprite 0
         ("0" & X"00", X"00"),
         ("0" & X"01", X"7E"),
         ("0" & X"02", X"00"),

         ("0" & X"03", X"C0"),
         ("0" & X"04", X"FF"),
         ("0" & X"05", X"03"),

         ("0" & X"06", X"E0"),
         ("0" & X"07", X"FF"),
         ("0" & X"08", X"07"),

         ("0" & X"09", X"F8"),
         ("0" & X"0A", X"FF"),
         ("0" & X"0B", X"1F"),

         ("0" & X"0C", X"F8"),
         ("0" & X"0D", X"FF"),
         ("0" & X"0E", X"1F"),

         ("0" & X"0F", X"FC"),
         ("0" & X"10", X"FF"),
         ("0" & X"11", X"3F"),

         ("0" & X"12", X"FE"),
         ("0" & X"13", X"FF"),
         ("0" & X"14", X"7F"),

         ("0" & X"15", X"FE"),
         ("0" & X"16", X"FF"),
         ("0" & X"17", X"7F"),

         ("0" & X"18", X"FF"),
         ("0" & X"19", X"FF"),
         ("0" & X"1A", X"FF"),

         ("0" & X"1B", X"FF"),
         ("0" & X"1C", X"FF"),
         ("0" & X"1D", X"FF"),

         ("0" & X"1E", X"FF"),
         ("0" & X"1F", X"FF"),
         ("0" & X"20", X"FF"),

         ("0" & X"21", X"FF"),
         ("0" & X"22", X"FF"),
         ("0" & X"23", X"FF"),

         ("0" & X"24", X"FF"),
         ("0" & X"25", X"FF"),
         ("0" & X"26", X"FF"),

         ("0" & X"27", X"FE"),
         ("0" & X"28", X"FF"),
         ("0" & X"29", X"7F"),

         ("0" & X"2A", X"FE"),
         ("0" & X"2B", X"FF"),
         ("0" & X"2C", X"7F"),

         ("0" & X"2D", X"FC"),
         ("0" & X"2E", X"FF"),
         ("0" & X"2F", X"3F"),

         ("0" & X"30", X"F8"),
         ("0" & X"31", X"FF"),
         ("0" & X"32", X"1F"),

         ("0" & X"33", X"F8"),
         ("0" & X"34", X"FF"),
         ("0" & X"35", X"1F"),

         ("0" & X"36", X"E0"),
         ("0" & X"37", X"FF"),
         ("0" & X"38", X"07"),

         ("0" & X"39", X"C0"),
         ("0" & X"3A", X"FF"),
         ("0" & X"3B", X"03"),

         ("0" & X"3C", X"00"),
         ("0" & X"3D", X"7E"),
         ("0" & X"3E", X"00"),

         ("1" & X"00", X"20"),   -- X position bits 7-0
         ("1" & X"01", X"00"),   -- X position MSB
         ("1" & X"02", X"00"),   -- Y position
         ("1" & X"03", X"F0"),   -- Color
         ("1" & X"04", X"01"),   -- Enable
         ("1" & X"05", X"00")    -- Behind
      );

   begin
      if rising_edge(clk_i) then
         cs   <= '0';
         wren <= '0';

         if counter < C_CONFIG'length then
            addr <= C_CONFIG(counter).addr;
            data <= C_CONFIG(counter).data;
            cs   <= '1';
            wren <= '1';
            counter <= counter + 1;
         end if;

         if rst_i = '1' then
            cs   <= '0';
            wren <= '0';
            counter <= 0;
         end if;
      end if;
   end process p_config;

   -----------------------
   -- Drive output signals
   -----------------------

   cs_o   <= cs;
   wren_o <= wren;
   addr_o <= addr;
   data_o <= data;

end architecture Structural;

