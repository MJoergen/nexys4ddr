-- Original MEGA65 keyboard driver file by Paul Gardner-Stephen
-- see AUTHORS details and license
--
-- Modified for gbc4mega65 by sy2002 in January 2021
-- Added to MiSTer2MEGA65 based on the modified gbc4mega65 form by sy2002 in July 2021

use WORK.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
--use work.debugtools.all;

entity matrix_to_keynum is
  generic (scan_frequency : integer := 1000);
  port (Clk : in std_logic;
        clock_frequency : in natural;
        reset_in : in std_logic;

        matrix_col : in std_logic_vector(7 downto 0);
        matrix_col_idx : in integer range 0 to 15;
        
        m65_key_num : out integer range 0 to 79;
        m65_key_status_n : out std_logic;
        
        suppress_key_glitches : in std_logic;
        suppress_key_retrigger : in std_logic;
        
        -- UART key stream
        ascii_key : out unsigned(7 downto 0) := (others => '0');
        -- Bucky key list:
        -- 0 = left shift
        -- 1 = right shift
        -- 2 = control
        -- 3 = C=
        -- 4 = ALT
        -- 5 = NO SCROLL
        -- 6 = ASC/DIN/CAPS LOCK (XXX - Has a separate line. Not currently monitored)
        bucky_key : out std_logic_vector(6 downto 0) := (others  => '0');
        ascii_key_valid : out std_logic := '0'
        );
end entity matrix_to_keynum;
  
architecture beh of matrix_to_keynum is
  -- Number of the highest key to read from the hardware controller's matrix RAM
  constant MAXKEY : integer := 79;
  
  -- Number of CPU cycles between each key scan event
  signal keyscan_delay : natural;  
  signal keyscan_counter : integer := 0;
  
  -- Automatic key repeat (just repeats ascii_key_valid strobe periodically)
  -- (As key repeat is checked on each of the 72 key tests, we don't need to
  -- divide the maximum repeat counters by 72.)
  signal repeat_key : integer range 0 to MAXKEY := 0;
  --signal repeat_start_timer : integer;
  signal repeat_again_timer : integer;

  signal ascii_key_valid_countdown : integer range 0 to 65535 := 0;

  signal repeat_key_timer : integer := 0;

  -- This one snoops the input and gets atomically snapshotted at each keyscan interval
  signal matrix_in : std_logic_vector(MAXKEY downto 0);

  signal matrix : std_logic_vector(MAXKEY downto 0) := (others => '1');
  signal bucky_key_internal : std_logic_vector(6 downto 0) := (others => '0');
  signal matrix_internal : std_logic_vector(MAXKEY downto 0) := (others => '1');

  -- These are the current single output bits from the debounce and last matrix rams
  signal debounce_key_state : std_logic;
  signal last_key_state : std_logic;
  
  -- This is the current index we are reading from both RAMs (and writing to last)
  signal ram_read_index : integer range 0 to 15;
  signal debounce_write_mask : std_logic_vector(7 downto 0);
  signal last_write_mask : std_logic_vector(7 downto 0);
  
  signal debounce_in : std_logic_vector(7 downto 0);
  signal current_col_out : std_logic_vector(7 downto 0);
  signal debounce_col_out : std_logic_vector(7 downto 0);
  signal last_col_out : std_logic_vector(7 downto 0);
  
  signal repeat_timer_expired : std_logic;
  
  signal reset : std_logic := '1';
  
--  type key_matrix_t is array(0 to MAXKEY) of unsigned(7 downto 0);
--  signal matrix_normal : key_matrix_t := (
--    0 => x"14", -- INS/DEL
--    1 => x"0D", -- RET/NO KEY
--    2 => x"1d", -- HORZ/CRSR
--    3 => x"f7", -- F8/F7
--    4 => x"f1", -- F2/F1
--    5 => x"f3", -- F4/F3
--    6 => x"f5", -- F6/F5
--    7 => x"11", -- VERT/CRSR
--    8 => x"33", -- #/3
--    9 => x"77", -- W/w
--    10 => x"61", -- A/a
--    11 => x"34", -- $/4
--    12 => x"7a", -- Z/z
--    13 => x"73", -- S/s
--    14 => x"65", -- E/e
--    15 => x"00", -- LEFT/SHIFT
--    16 => x"35", -- %/5
--    17 => x"72", -- R/r
--    18 => x"64", -- D/d
--    19 => x"36", -- &/6
--    20 => x"63", -- C/c
--    21 => x"66", -- F/f
--    22 => x"74", -- T/t
--    23 => x"78", -- X/x
--    24 => x"37", -- '/7
--    25 => x"79", -- Y/y
--    26 => x"67", -- G/g
--    27 => x"38", -- (/8
--    28 => x"62", -- B/b
--    29 => x"68", -- H/h
--    30 => x"75", -- U/u
--    31 => x"76", -- V/v
--    32 => x"39", -- )/9
--    33 => x"69", -- I/i
--    34 => x"6a", -- J/j
--    35 => x"30", -- 0/0
--    36 => x"6d", -- M/m
--    37 => x"6b", -- K/k
--    38 => x"6f", -- O/o
--    39 => x"6e", -- N/n
--    40 => x"2b", -- NO KEY/+
--    41 => x"70", -- P/p
--    42 => x"6c", -- L/l
--    43 => x"2d", -- NO KEY/-
--    44 => x"2e", -- >/.
--    45 => x"3a", -- [/:
--    46 => x"40", -- @
--    47 => x"2c", -- </,
--    48 => x"A3", -- British pound
--    49 => x"2a", -- *
--    50 => x"3b", -- ]/;
--    51 => x"13", -- CLR/HOM
--    52 => x"00", -- RIGHT/SHIFT
--    53 => x"3d", -- }/=
--    54 => x"e0", -- ARROW UP KEY
--    55 => x"2f", -- ?//
--    56 => x"31", -- !/1
--    57 => x"ea", -- ARROW LEFT KEY
--    58 => x"00", -- CTRL/NO KEY
--    59 => x"32", -- "/2
--    60 => x"20", -- SPACE/BAR
--    61 => x"00", -- C=/NO KEY
--    62 => x"71", -- Q/q
--    63 => x"03", -- RUN/STOP
--    64 => x"00", -- NO/SCRL
--    65 => x"09", -- TAB
--    66 => x"00", -- ALT/NO KEY
--    67 => x"00", -- HELP/NO KEY
--    68 => x"f9", -- F10/F9
--    69 => x"fb", -- F12/F11
--    70 => x"fd", -- F14/F13
--    71 => x"1b", -- ESC/NO KEY
--    72 => x"00", -- CAPSLOCK (ignore, handled otherwise)
--    73 => x"91", -- CURSOR UP = SHIFT+VERT/CRSR
--    74 => x"9d", -- CURSOR LEFT = SHIFT+HORZ/CRSR
--    75 => x"00",
--    76 => x"00",
--    77 => x"00",
--    78 => x"00",
--    79 => x"00",

--    others => x"00"
--    );

  
  signal key_num : integer range 0 to MAXKEY := 0;

begin

  -- The clock_frequency of the system is not changing very often. At some cores that switch between
  -- PAL and NTSC, it is for example changing. Therefore we can do the following math combinatorially
  -- as long as we constrain it correctly in the XDC file (for example using False Paths)
  -- As long as the core only uses one clock frequency, then Vivado will be able to treat everything
  -- here as constants and optimize away any logic, so that there is nothing to constrain in the XDC file.
  -- @TODO We need to find a more elegant solution in future
  keyscan_delay      <= clock_frequency / (72 * scan_frequency);
  --repeat_start_timer <= clock_frequency / scan_frequency / 2;  -- 0.5 sec
  repeat_again_timer <= clock_frequency / scan_frequency / 10; -- 0.1 sec
  
  -- This is our first local copy that gets updated continuously by snooping
  -- the incoming column state from the keymapper.  It exists mostly so we have
  -- an updated copy of the current matrix state we can sample from at our own
  -- pace.
  current_kmm: entity work.kb_matrix_ram
  port map (
    clkA => Clk,
    addressa => matrix_col_idx,
    dia => matrix_col,
    wea => x"FF",
    addressb => ram_read_index,
    dob => current_col_out
    );
  
  -- This is a second copy we use for debouncing the input.  It's input is either
  -- the current_col_out (if we're sampling) or the logical and of current_col_out
  -- and debounce_col_out (if we're debouncing)
  debounce_kmm : entity work.kb_matrix_ram
  port map (
    clkA => Clk,
    addressa => ram_read_index,
    dia => debounce_in,
    wea => debounce_write_mask,
    addressb => ram_read_index,
    dob => debounce_col_out
    );
    
  -- This is our third local copy which we use for detecting edges.  It gets 
  -- updated as we do the key scan and always remembers the last state of whatever
  -- key we're currently looking at.
  last_kmm: entity work.kb_matrix_ram
  port map (
    clkA => Clk,
    addressa => ram_read_index,
    dia => current_col_out,
    wea => last_write_mask,
    addressb => ram_read_index,
    dob => last_col_out
    );
    
    -- combinatorial processes
  process(ram_read_index,debounce_col_out,current_col_out,last_col_out,keyscan_counter,key_num,suppress_key_glitches)
    variable read_index : integer range 0 to 15;
    variable key_num_vec : std_logic_vector(6 downto 0);
    variable key_num_bit : integer range 0 to 7;
    variable key_num_bit_chop : unsigned(2 downto 0);
    variable debounce_mask : std_logic_vector(7 downto 0);
    variable last_mask : std_logic_vector(7 downto 0);
    variable dks : std_logic;
    variable lks : std_logic;
  begin
      read_index := 0;
      debounce_mask := x"00";
      last_mask := x"00";
      key_num_vec := "0000000";
      key_num_bit := 0;
      dks := '1';
      lks := '1';
      
      if keyscan_counter /= 0 then
        if(keyscan_counter < 11) then
          read_index := keyscan_counter - 1;
          debounce_mask := x"FF";
        end if;
        if suppress_key_glitches='1' then
          debounce_in <= current_col_out and debounce_col_out;
        else
          debounce_in <= current_col_out;
        end if;
      else
        debounce_in <= current_col_out;
        key_num_vec   := std_logic_vector(to_unsigned(key_num,7));
        read_index    := to_integer(unsigned(key_num_vec(6 downto 3)));
        key_num_bit   := to_integer(unsigned(key_num_vec(2 downto 0)));
        key_num_bit_chop := to_unsigned(key_num_bit,7)(2 downto 0);
        case key_num_bit_chop is
          when "000" => last_mask := "00000001";
          when "001" => last_mask := "00000010";
          when "010" => last_mask := "00000100";
          when "011" => last_mask := "00001000";
          when "100" => last_mask := "00010000";
          when "101" => last_mask := "00100000";
          when "110" => last_mask := "01000000";
          when "111" => last_mask := "10000000";
          when others => last_mask := x"00";
        end case;
        debounce_mask := last_mask;
        dks := debounce_col_out(key_num_bit);
        lks := last_col_out(key_num_bit);
      end if;
      
      -- update debounce and last bits
      debounce_key_state <= dks;
      last_key_state <= lks;
      
      -- update other ram input signals
      ram_read_index <= read_index;
      debounce_write_mask <= debounce_mask;
      last_write_mask <= last_mask;
  end process;
  
  process(clk)
--    variable key_matrix : key_matrix_t;
  begin
    if rising_edge(clk) then

      -- CAPS LOCK key like others is active low, so we invert it when
      -- recording its status.
      --bucky_key_internal(6) <= not key_caps;
                     
      --reset <= reset_in;
      --if reset_in /= reset then
      --  matrix_internal <= (others => '1');
      --  matrix <= (others => '1');
      --end if;
      
      --matrix_in(matrix_col_idx*8+7 downto matrix_col_idx*8) <= matrix_col;
      
      -- Which matrix to use, based on modifier key state
      -- C= takes precedence over SHIFT, so that we can have C= + cursor keys
      -- as unique keys
--      if bucky_key_internal(3)='1' then
--        key_matrix := matrix_cbm;
--      elsif bucky_key_internal(4)='1' then
--        key_matrix := matrix_alt;
--      elsif bucky_key_internal(0)='1' or bucky_key_internal(1)='1' or key_up='1' or key_left='1' then
--        -- Force shifted key set if UP or LEFT keys active, to try to prevent
--        -- glitching of those keys.
--        key_matrix := matrix_shift;
--      elsif bucky_key_internal(2)='1' then
--        key_matrix := matrix_control;
--      else
--        key_matrix := matrix_normal;
--      end if;

--      key_matrix := matrix_normal;

      bucky_key <= bucky_key_internal;

      -- Check for key press events
      if keyscan_counter /= 0 then
        keyscan_counter <= keyscan_counter - 1;
        ascii_key_valid <= '0';
      else
--        report "Checking matrix for key event, matrix=" & to_string(matrix);

        -- Update modifiers
        case key_num is
          when 15 => bucky_key_internal(0) <= not debounce_key_state; -- LEFT/LOCK_SHIFT
          when 52 => bucky_key_internal(1) <= not debounce_key_state; -- RIGHT_SHIFT
          when 58 => bucky_key_internal(2) <= not debounce_key_state; -- CTRL
          when 61 => bucky_key_internal(3) <= not debounce_key_state; -- MEGA
          when 66 => bucky_key_internal(4) <= not debounce_key_state; -- ALT
          when 64 => bucky_key_internal(5) <= not debounce_key_state; -- NO_SCROLL
          -- XXX CAPS LOCK has its own separate line, so is set elsewhere
          when others => null;
        end case;
        
        m65_key_num <= key_num;
        m65_key_status_n <= debounce_key_state;
        
        keyscan_counter <= keyscan_delay;

--        if (last_key_state = '1') and (debounce_key_state='0') then
--          if key_matrix(key_num) /= x"00" then
--            -- Key press event
--            --report "matrix = " & to_string(matrix);
--            --report "key press, ASCII code = " & to_hstring(key_matrix(key_num));

--            ascii_key <= key_matrix(key_num);
            
--            -- Make CAPS LOCK invert case of only letters
--            if bucky_key_internal(6)='1'
--              and (
--                ((to_integer(key_matrix(key_num)) >= (96+1))
--                 and (to_integer(key_matrix(key_num)) <= (96+26)))
--                or (bucky_key_internal(4) = '1')
--                )
--                then
--                  -- Clear bit 5 ($20) to convert lower to upper case letters
--                  -- (Applies to some weird Latin1 characters, regardless of
--                  -- the symbol.)
--              ascii_key(5) <= '0';
--            end if;
            
--            repeat_key <= key_num;
--            repeat_key_timer <= repeat_start_timer;
--            ascii_key_valid_countdown <= 1023;
--            ascii_key_valid <= '0';
--          else
--            ascii_key_valid <= '0';
--          end if;
--        else
--          if repeat_key_timer /= 0 then
--            repeat_key_timer <= repeat_key_timer - 1;
--            ascii_key_valid <= '0';
--          elsif repeat_timer_expired = '1' then
--            --repeat_key_timer <= repeat_again_timer;
--            if (repeat_key = key_num) and debounce_key_state='0' then
--              ascii_key_valid <= '1';
--              --report "Repeating key held down";
--              -- Republish the key, so that modifiers can change during repeat,
--              -- e.g., to allow cursor direction changing without stopping the
--              -- repeat.
--              ascii_key <= key_matrix(repeat_key);
--              --else
--              --ascii_key_valid <= '0';              
--            end if;
--          end if;
--        end if;

--        -- Do delayed presentation of down/right, modifying it to up/left if
--        -- the shift key has gone down in the meantime.
--        if ascii_key_valid_countdown = 1 then
--          ascii_key_valid_countdown <= 0;
--          ascii_key_valid <= '1';
--        elsif ascii_key_valid_countdown /= 0 then
--          ascii_key_valid_countdown <= ascii_key_valid_countdown - 1;
--        else
--          null;
--        end if;
        
        if key_num /= MAXKEY then
          key_num <= key_num + 1;
        else
          key_num <= 0;
          -- If we hit key_num MAXKEY and the repeat key has expired then reset it.
          -- otherwise we set it so we do the repeat check on the next pass and
          -- then reset it.
          if repeat_timer_expired = '1' then
            repeat_key_timer <= repeat_again_timer;
            repeat_timer_expired <= '0';
          elsif repeat_key_timer = 0 then
            repeat_timer_expired <= '1';
          end if;
        end if;
      end if;
      
    end if;
    
  end process;
end beh;
  


