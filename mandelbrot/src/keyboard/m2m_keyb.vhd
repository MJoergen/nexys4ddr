----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- MEGA65 keyboard controller
--
-- Runs in the clock domain of the core.
--
-- There are three purposes of this controller:
--
-- 1) Serve key_num and key_status to the core's keyboard.vhd, so that there the
--    core specific keyboard mapping can take place.
--
-- 2) Serve qnice_keys to QNICE and the firmware, so that the Shell can rely
--    on certain mappings (and behaviors) to be always available, independent
--    of the core specific way to handle the keyboard.
--
-- 3) Control the drive led
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity m2m_keyb is
   generic (
      SCAN_FREQUENCY       : integer := 1000                   -- keyboard scan frequency in Herz, default: 1 kHz      
   );
   port (
      clk_main_i           : in std_logic;                     -- core clock
      clk_main_speed_i     : in natural;                       -- speed of core clock in Hz
       
      -- interface to the MEGA65 keyboard controller       
      kio8_o               : out std_logic;                    -- clock to keyboard
      kio9_o               : out std_logic;                    -- data output to keyboard
      kio10_i              : in std_logic;                     -- data input from keyboard
      
      -- interface to the core
      enable_core_i        : in std_logic;                     -- 0 = core is decoupled from the keyboard, 1 = standard operation      
      key_num_o            : out integer range 0 to 79;        -- cycles through all keys with SCAN_FREQUENCY
      key_pressed_n_o      : out std_logic;                    -- low active: debounced feedback: is kb_key_num_o pressed right now?

      -- control the drive led on the MEGA65 keyboard
      power_led_i          : in std_logic;
      power_led_col_i      : in std_logic_vector(23 downto 0); -- RGB color of power led      
      drive_led_i          : in std_logic;
      drive_led_col_i      : in std_logic_vector(23 downto 0); -- RGB color of drive led
            
      -- interface to QNICE: used by the firmware and the Shell (see sysdef.asm for details)
      qnice_keys_n_o       : out std_logic_vector(15 downto 0)
   );
end m2m_keyb;

architecture beh of m2m_keyb is

signal matrix_col          : std_logic_vector(7 downto 0);
signal matrix_col_idx      : integer range 0 to 9 := 0;
signal key_num             : integer range 0 to 79;
signal key_status_n        : std_logic;
signal keys_n              : std_logic_vector(15 downto 0) := x"FFFF"; -- low active, "no key pressed"

begin
   -- output the keyboard interface for the core
   key_num_o         <= key_num;
   key_pressed_n_o   <= key_status_n when enable_core_i else '1';
   
   -- output the keyboard interface for QNICE
   qnice_keys_n_o    <= keys_n;
   
   m65driver : entity work.mega65kbd_to_matrix
   port map
   (
       ioclock          => clk_main_i,
       clock_frequency  => clk_main_speed_i,
      
       -- _steady means that the led stays on steadily
       -- _blinking means that the led is blinking
       -- The colors are specified as BGR (reverse RGB)
       powerled_steady     => power_led_i,
       powerled_col        => power_led_col_i(7 downto 0) & power_led_col_i(15 downto 8) & power_led_col_i(23 downto 16), -- RGB to BGR
       driveled_steady     => drive_led_i,
       driveled_blinking   => '0',   
       driveled_col        => drive_led_col_i(7 downto 0) & drive_led_col_i(15 downto 8) & drive_led_col_i(23 downto 16), -- RGB to BGR    
       
       kio8             => kio8_o,
       kio9             => kio9_o,
       kio10            => kio10_i,
      
       matrix_col       => matrix_col,
       matrix_col_idx   => matrix_col_idx,
       
       capslock_out     => open  
   );
   
   m65matrix_to_keynum : entity work.matrix_to_keynum
   generic map
   (
      scan_frequency    => SCAN_FREQUENCY  
   )
   port map
   (
      clk               => clk_main_i,
      clock_frequency   => clk_main_speed_i,
      reset_in          => '0',

      matrix_col => matrix_col,
      matrix_col_idx => matrix_col_idx,
      
      m65_key_num => key_num,
      m65_key_status_n => key_status_n,
      
      suppress_key_glitches => '1',
      suppress_key_retrigger => '0',
      
      bucky_key => open   
   );
   
   matrix_col_idx_handler : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if matrix_col_idx < 9 then
           matrix_col_idx <= matrix_col_idx + 1;
         else
           matrix_col_idx <= 0;
         end if;      
      end if;
   end process;      
   
   -- make qnice_keys_o a register and fill it
   -- see sysdef.asm for the key-to-bit mapping      
   handle_qnice_keys : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then      
         case key_num is
            when 73        => keys_n(0) <= key_status_n;     -- Cursor up
            when 7         => keys_n(1) <= key_status_n;     -- Cursor down
            when 74        => keys_n(2) <= key_status_n;     -- Cursor left
            when 2         => keys_n(3) <= key_status_n;     -- Cursor right
            when 1         => keys_n(4) <= key_status_n;     -- Return
            when 60        => keys_n(5) <= key_status_n;     -- Space
            when 63        => keys_n(6) <= key_status_n;     -- Run/Stop
            when 67        => keys_n(7) <= key_status_n;     -- Help
            when 4         => keys_n(8) <= key_status_n;     -- F1
            when 5         => keys_n(9) <= key_status_n;     -- F3
            when others    => null;
         end case;
      end if;
   end process;   
end beh;
