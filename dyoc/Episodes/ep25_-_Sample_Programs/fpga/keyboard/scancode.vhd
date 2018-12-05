library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity scancode is
   port (
      clk_i      : in  std_logic;
 
      keycode_i  : in  std_logic_vector(7 downto 0);
      valid_i    : in  std_logic;
      ascii_o    : out std_logic_vector(7 downto 0);
      valid_o    : out std_logic
   );
end entity scancode;

architecture structural of scancode is

   constant KBD_SHIFT_LEFT  : std_logic_vector(7 downto 0) := X"12";
   constant KBD_SHIFT_RIGHT : std_logic_vector(7 downto 0) := X"59";
   constant KBD_RELEASE     : std_logic_vector(7 downto 0) := X"F0";

   subtype t_ascii is std_logic_vector(7 downto 0);
   type t_keytab is array(0 to 127) of t_ascii;

   constant keytab_normal : t_keytab := (
      X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"71", X"31", X"00", X"00", X"00", X"7A", X"73", X"61", X"77", X"32", X"00",
      X"00", X"63", X"78", X"64", X"65", X"34", X"33", X"00", X"00", X"20", X"76", X"66", X"74", X"72", X"35", X"00",
      X"00", X"6E", X"62", X"68", X"67", X"79", X"36", X"00", X"00", X"00", X"6D", X"6A", X"75", X"37", X"38", X"00",
      X"00", X"2C", X"6B", X"69", X"6F", X"30", X"39", X"00", X"00", X"2E", X"2D", X"6C", X"E6", X"70", X"2B", X"00",
      X"00", X"00", X"F8", X"00", X"E5", X"00", X"00", X"00", X"00", X"00", X"0D", X"7E", X"00", X"27", X"00", X"00",
      X"00", X"3C", X"00", X"00", X"00", X"00", X"08", X"00", X"00", X"03", X"00", X"1B", X"02", X"00", X"00", X"00",
      X"00", X"7F", X"00", X"00", X"1A", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00"
   );

   constant keytab_shifted : t_keytab := (
      X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"51", X"21", X"00", X"00", X"00", X"5A", X"53", X"41", X"57", X"22", X"00",
      X"00", X"43", X"58", X"44", X"45", X"24", X"23", X"00", X"00", X"20", X"56", X"46", X"54", X"52", X"25", X"00",
      X"00", X"4E", X"42", X"48", X"47", X"59", X"26", X"00", X"00", X"00", X"4D", X"4A", X"55", X"2F", X"28", X"00",
      X"00", X"3B", X"4B", X"49", X"4F", X"3D", X"29", X"00", X"00", X"3A", X"5F", X"4C", X"C6", X"50", X"3F", X"00",
      X"00", X"00", X"D8", X"00", X"C5", X"00", X"00", X"00", X"00", X"00", X"0D", X"5E", X"00", X"2A", X"00", X"00",
      X"00", X"3E", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00",
      X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00"
   );

   signal releasemode : std_logic;
   signal shifted     : std_logic;

   signal ascii       : std_logic_vector(7 downto 0);
   signal valid       : std_logic := '0';

begin

   --------------------------------
   -- State machine
   --------------------------------

   fsm_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         valid <= '0';

         if valid_i = '1' then
            if releasemode = '1' then
               releasemode <= '0';
               if keycode_i = KBD_SHIFT_LEFT or keycode_i = KBD_SHIFT_RIGHT then
                  shifted <= '0';
               end if;
            else
               case keycode_i is
                  when KBD_RELEASE     => releasemode <= '1';
                  when KBD_SHIFT_LEFT  => shifted <= '1';
                  when KBD_SHIFT_RIGHT => shifted <= '1';
                  when others => 
                     if keycode_i(7) = '0' then
                        if shifted = '1' then
                           ascii <= keytab_shifted(to_integer(keycode_i(6 downto 0)));
                           valid <= '1';
                        else
                           ascii <= keytab_normal(to_integer(keycode_i(6 downto 0)));
                           valid <= '1';
                        end if;
                     end if;
               end case;
            end if;  -- else
         end if;   -- valid_i = '1'
      end if;
   end process fsm_proc;


   -----------------------
   -- Drive output signals
   -----------------------

   ascii_o <= ascii;
   valid_o <= valid;

end architecture structural;

