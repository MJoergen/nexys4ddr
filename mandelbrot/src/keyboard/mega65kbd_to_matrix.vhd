-- Original MEGA65 keyboard driver file by Paul Gardner-Stephen
-- see AUTHORS details and license
--
-- Modified for gbc4mega65 by sy2002 in January 2021
-- Added to MiSTer2MEGA65 based on the modified gbc4mega65 form by sy2002 in July 2021
-- Renamed signals, added documentation and made led color configurable by sy2002 in October 2022
-- Added a "for now good enough" solution for arbitrary ioclock frequencies (sy2002, December 2022)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use Std.TextIO.all;
--use work.debugtools.all;

entity mega65kbd_to_matrix is
  port (
    ioclock : in std_logic;
    clock_frequency : in natural;

    -- _steady means that the led stays on steadily
    -- _blinking means that the led is blinking
    -- The colors are specified as BGR (reverse RGB)
    powerled_steady        : in std_logic;
    powerled_col           : in std_logic_vector(23 downto 0);
    driveled_steady        : in std_logic;
    driveled_blinking      : in std_logic;   
    driveled_col           : in std_logic_vector(23 downto 0);

    matrix_col : out std_logic_vector(7 downto 0) := (others => '1');
    matrix_col_idx : in integer range 0 to 9;

    delete_out : out std_logic;
    return_out : out std_logic;
    fastkey_out : out std_logic;
    
    -- RESTORE and capslock are active low
    restore : out std_logic := '1';
    capslock_out : out std_logic := '1';

    -- LEFT and UP cursor keys are active HIGH
    leftkey : out std_logic := '0';
    upkey : out std_logic := '0';
    
    -- interface to Lattice FPGA
    kio8 : out std_logic; -- clock to keyboard
    kio9 : out std_logic; -- data output to keyboard
    kio10 : in std_logic  -- data input from keyboard    
    );

end entity mega65kbd_to_matrix;

architecture behavioural of mega65kbd_to_matrix is

  signal matrix_ram_offset : integer range 0 to 15 := 0;
  signal keyram_wea : std_logic_vector(7 downto 0);
  signal keyram_dia : std_logic_vector(7 downto 0);
  signal matrix_dia : std_logic_vector(7 downto 0);
  
  signal enabled : std_logic := '0';

  signal clock_divider : integer range 0 to 65535 := 0;
  signal clock_divider_target : integer range 0 to 65535;
  
  signal kbd_clock : std_logic := '0';
  signal phase : integer range 0 to 255 := 0;
  signal sync_pulse : std_logic := '0';

  signal counter : unsigned(26 downto 0) := to_unsigned(0,27);
  
  signal output_vector : std_logic_vector(127 downto 0);

  signal deletekey : std_logic := '1';
  signal returnkey : std_logic := '1';
  signal fastkey : std_logic := '1';
  
begin  -- behavioural

  -- @TODO as of December 2022 (by sy2002): We need to find a smarter solution. This only works well
  -- as long as we only have one constant core frequency; otherwise a large combinatorial net will be
  -- created and we would need to add false-paths to the XDC (see also lines 179+ in matrix_to_keynum.vhdl)
  -- In the original MEGA65 code, the value is 64 for a 40 MHz clock, i.e. (40000000/64/2) 312.500 Hz.
  -- Let's make sure approximate this value well enough.
  clock_divider_target <= clock_frequency / 2 / 312500;

  widget_kmm: entity work.kb_matrix_ram
    port map (
      clkA => ioclock,
      addressa => matrix_ram_offset,
      dia => matrix_dia,
      wea => keyram_wea,
      addressb => matrix_col_idx,
      dob => matrix_col
      );

  process (ioclock)
    variable keyram_write_enable : std_logic_vector(7 downto 0);
    variable keyram_offset : integer range 0 to 15 := 0;
    variable keyram_offset_tmp : std_logic_vector(2 downto 0);
    
  begin
    if rising_edge(ioclock) then
      ------------------------------------------------------------------------
      -- Read from MEGA65R2 keyboard
      ------------------------------------------------------------------------
      -- Process is to run a clock at a modest rate, and periodically send
      -- a sync pulse, and clock in the key states, while clocking out the
      -- LED states.

      delete_out <= deletekey;
      return_out <= returnkey;
      fastkey_out <= fastkey;
      
      -- Counter is for working out drive LED blink phase
      counter <= counter + 1;
    
      -- Default is no write nothing at offset zero into the matrix ram.
      keyram_write_enable := x"00";
      keyram_offset := 0;

      -- modified by sy2002 in December 2022
      if clock_divider /= clock_divider_target then
        clock_divider <= clock_divider + 1;
      else
        clock_divider <= 0;

        kbd_clock <= not kbd_clock;
        kio8 <= kbd_clock or sync_pulse;

        if kbd_clock='1' and phase < 128 then
          keyram_offset := phase/8;

          -- Receive keys with dedicated lines
          if phase = 72 then
            capslock_out <= kio10;
          end if;
          if phase = 73 then
            upkey <= not kio10;
          end if;
          if phase = 74 then
            leftkey <= not kio10;
          end if;
          if phase = 75 then
            restore <= kio10;
          end if;
          if phase = 76 then
            deletekey <= kio10;
          end if;
          if phase = 77 then
            returnkey <= kio10;
          end if;
          if phase = 78 then
            fastkey <= kio10;
          end if;
          
          -- Work around the data arriving 2 cycles late from the keyboard controller
          if phase = 0 then
            matrix_dia <= (others => deletekey);
          elsif phase = 1 then
            matrix_dia <= (others => returnkey);
          else
            matrix_dia <= (others => kio10); -- present byte of input bits to
                                             -- ram for writing
          end if;
          
          
          --report "Writing received bit " & std_logic'image(kio10) & " to bit position " & integer'image(phase);
          
          case (phase mod 8) is
            when 0 => keyram_write_enable := x"01";
            when 1 => keyram_write_enable := x"02";
            when 2 => keyram_write_enable := x"04";
            when 3 => keyram_write_enable := x"08";
            when 4 => keyram_write_enable := x"10";
            when 5 => keyram_write_enable := x"20";
            when 6 => keyram_write_enable := x"40";
            when 7 => keyram_write_enable := x"80";
            when others => null;
          end case;
        end if;        
        matrix_ram_offset <= keyram_offset;
        keyram_wea <= keyram_write_enable;
        
        if kbd_clock='0' then
          --report "phase = " & integer'image(phase) & ", sync=" & std_logic'image(sync_pulse);
          if phase /= 140 then
            phase <= phase + 1;
          else
            phase <= 0;
          end if;
          if phase = 127 then
            -- Reset to start
            sync_pulse <= '1';
            output_vector <= (others => '0');
            if driveled_steady='1' or (driveled_blinking='1' and counter(24)='1') then
              output_vector(23 downto 0)  <= driveled_col;
              output_vector(47 downto 24) <= driveled_col;
            end if;
            if powerled_steady='1' then
              output_vector(71 downto 48) <= powerled_col;
              output_vector(95 downto 72) <= powerled_col;
            end if;
          elsif phase = 140 then
            sync_pulse <= '0';
          elsif phase < 127 then
            -- Output next bit
            kio9 <= output_vector(127);
            output_vector(127 downto 1) <= output_vector(126 downto 0);
            output_vector(0) <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

end behavioural;
