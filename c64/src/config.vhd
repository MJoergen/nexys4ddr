library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity config is

   generic (
      G_SIMULATION : string
   );
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      addr_o : out std_logic_vector( 6 downto 0);
      wren_o : out std_logic;
      data_o : out std_logic_vector(15 downto 0);
      rden_o : out std_logic;
      data_i : in  std_logic_vector(15 downto 0)
   );

end entity config;

architecture Structural of config is

   function get_counter_size (simulation : string) return integer
   is
   begin
      if simulation = "yes" then
         return 5;
      else
         return 500000;
      end if;

   end function;

   constant C_COUNT_MAX : integer := get_counter_size(G_SIMULATION);

   signal init_wren    : std_logic;
   signal init_addr    : std_logic_vector( 7 downto 0);
   signal init_data    : std_logic_vector(15 downto 0);
   signal init_counter : integer := 0;

   signal move_counter : integer range 0 to C_COUNT_MAX := 0;
   signal move_now     : std_logic;

   signal posx         : std_logic_vector(15 downto 0) := (others => '0');
   signal posy         : std_logic_vector(15 downto 0) := (others => '0');

   signal move_rden    : std_logic;
   signal move_wren    : std_logic;
   signal move_addr    : std_logic_vector( 7 downto 0) := (others => '0');
   signal move_data    : std_logic_vector(15 downto 0) := (others => '0');

   -- State machine to control the CPU
   type t_fsm_state is (FSM_INIT, FSM_IDLE, FSM_MOVE_X, FSM_MOVE_Y);
   signal fsm_state : t_fsm_state := FSM_INIT;


   type t_config is record
      addr : std_logic_vector( 7 downto 0);
      data : std_logic_vector(15 downto 0);
   end record t_config;

   type t_config_vector is array (natural range <>) of t_config;

   constant C_CONFIG : t_config_vector := (
      -- Sprite 0
      (X"00", B"00000000_00000000"),
      (X"01", B"00000000_00000000"),
      (X"02", B"00000001_10000000"),
      (X"03", B"00000110_01100000"),
      (X"04", B"00001000_00010000"),
      (X"05", B"00010000_00001000"),
      (X"06", B"00010000_00001000"),
      (X"07", B"00100000_00000100"),
      (X"08", B"00100000_00000100"),
      (X"09", B"00010000_00001000"),
      (X"0A", B"00010000_00001000"),
      (X"0B", B"00001000_00010000"),
      (X"0C", B"00000110_01100000"),
      (X"0D", B"00000001_10000000"),
      (X"0E", B"00000000_00000000"),
      (X"0F", B"00000000_00000000"),

      (X"10", X"0020"),   -- X position bits 8-0
      (X"11", X"0000"),   -- Y position
      (X"12", X"00F0"),   -- Color
      (X"13", X"0001"),   -- Enable

      -- Sprite 1
      (X"20", "1111111111111111"),
      (X"21", "1000000000000001"),
      (X"22", "1000000000000001"),
      (X"23", "1000000000000001"),
      (X"24", "1000000000000001"),
      (X"25", "1000000000000001"),
      (X"26", "1000000000000001"),
      (X"27", "1000000000000001"),
      (X"28", "1000000000000001"),
      (X"29", "1000000000000001"),
      (X"2A", "1000000000000001"),
      (X"2B", "1000000000000001"),
      (X"2C", "1000000000000001"),
      (X"2D", "1000000000000001"),
      (X"2E", "1000000000000001"),
      (X"2F", "1111111111111111"),

      (X"34", X"0023"),   -- X position bits 8-0
      (X"35", X"0000"),   -- Y position
      (X"36", X"00AA"),   -- Color
      (X"37", X"0001"),   -- Enable

      -- Sprite 2
      (X"40", "0000000000000000"),
      (X"41", "0000000110000000"),
      (X"42", "0000011111100000"),
      (X"43", "0000111111110000"),
      (X"44", "0001111111111000"),
      (X"45", "0011111111111100"),
      (X"46", "0000011111111100"),
      (X"47", "0000000111111110"),
      (X"48", "0000000111111110"),
      (X"49", "0000011111111100"),
      (X"4A", "0011111111111100"),
      (X"4B", "0001111111111000"),
      (X"4C", "0000111111110000"),
      (X"4D", "0000011111100000"),
      (X"4E", "0000000110000000"),
      (X"4F", "0000000000000000"),

      (X"50", X"0020"),   -- X position bits 8-0
      (X"51", X"0040"),   -- Y position
      (X"52", X"0055"),   -- Color
      (X"53", X"0001"),   -- Enable

      -- Sprite 3
      (X"60", "0000011111100000"),
      (X"61", "0000010000100000"),
      (X"62", "0000010000100000"),
      (X"63", "0000011111100000"),
      (X"64", "1100000110000011"),
      (X"65", "1111001111001111"),
      (X"66", "0001111111111000"),
      (X"67", "0000001111000000"),
      (X"68", "0000001111000000"),
      (X"69", "0000001111000000"),
      (X"6A", "0000011111100000"),
      (X"6B", "0000111001110000"),
      (X"6C", "0001100000011000"),
      (X"6D", "0011000000001100"),
      (X"6E", "0111000000001110"),
      (X"6F", "0110000000000110"),

      (X"70", X"0080"),   -- X position bits 8-0
      (X"71", X"00C0"),   -- Y position
      (X"72", X"000F"),   -- Color
      (X"73", X"0001")    -- Enable

   );

begin

   p_init : process (clk_i)
   begin
      if rising_edge(clk_i) then
         init_wren <= '0';

         if init_counter < C_CONFIG'length then
            init_addr <= C_CONFIG(init_counter).addr;
            init_data <= C_CONFIG(init_counter).data;
            init_wren <= '1';
            init_counter <= init_counter + 1;
         end if;

         if rst_i = '1' then
            init_wren    <= '0';
            init_counter <= 0;
         end if;
      end if;
   end process p_init;


   p_move : process (clk_i)
   begin
      if rising_edge(clk_i) then
         move_now <= '0';

         if move_counter = C_COUNT_MAX then
            move_counter <= 0;
            move_now <= '1';
         else
            move_counter <= move_counter + 1;
         end if;
      end if;
   end process p_move;


   -- Here we use the semi-implicit Euler method:
   -- x1 = x0 - y0*dt
   -- y1 = y0 + x1*dt
   -- We are using the value dt = 1/256.
   p_pos : process (clk_i)
      variable newx_v : std_logic_vector(15 downto 0);

      function sign_extend(arg : std_logic_vector(7 downto 0))
      return std_logic_vector is
         variable res : std_logic_vector(15 downto 0);
      begin
         res := (others => arg(7)); -- Copy sign bit to all bits.
         res(7 downto 0) := arg;
         return res;
      end function sign_extend;

   begin
      if rising_edge(clk_i) then
         if move_now = '1' then
            newx_v := posx - sign_extend(posy(15 downto 8));   -- x0 - y0*dt
            posy <= posy + sign_extend(newx_v(15 downto 8));   -- y0 + x1*dt
            posx <= newx_v;
         end if;

         -- Start at the position (64, 0), i.e. a radius of 64.
         if rst_i = '1' then
            posx <= X"4000";
            posy <= X"0000";
         end if;
      end if;
   end process p_pos;

   
   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         move_wren <= '0';
         move_rden <= '0';

         case fsm_state is
            when FSM_INIT =>
               if init_counter = C_CONFIG'length then
                  fsm_state <= FSM_IDLE;
               end if;

            when FSM_IDLE =>
               if move_now = '1' then
                  fsm_state <= FSM_MOVE_X;
               end if;

            when FSM_MOVE_X =>
               move_addr <= X"10";
               move_data(15 downto 8) <= X"00";
               move_data(7 downto 0)  <= posx(15 downto 8) + X"80";
               move_wren <= '1';
               fsm_state <= FSM_MOVE_Y;

            when FSM_MOVE_Y =>
               move_addr <= X"11";
               move_data(15 downto 8) <= X"00";
               move_data(7 downto 0)  <= posy(15 downto 8) + X"80";
               move_wren <= '1';
               fsm_state <= FSM_IDLE;

            when others =>
               fsm_state <= FSM_IDLE;
         end case;
      end if;
   end process p_fsm;


   ---------------------------
   -- Register output signals
   ---------------------------

   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if fsm_state = FSM_INIT then
            addr_o <= init_addr(6 downto 0);
            wren_o <= init_wren;
            data_o <= init_data;
            rden_o <= '0';
         else
            addr_o <= move_addr(6 downto 0);
            wren_o <= move_wren;
            data_o <= move_data;
            rden_o <= move_rden;
         end if;
      end if;
   end process p_out;

end architecture Structural;

