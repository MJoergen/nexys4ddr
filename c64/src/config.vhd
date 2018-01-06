library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

entity config is

   generic (
      G_SIMULATION : string
   );
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      wren_o : out std_logic;
      addr_o : out std_logic_vector( 8 downto 0);
      data_o : out std_logic_vector(15 downto 0)
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
   signal init_addr    : std_logic_vector( 8 downto 0);
   signal init_data    : std_logic_vector(15 downto 0);
   signal init_counter : integer := 0;

   signal move_counter : integer range 0 to C_COUNT_MAX := 0;
   signal move_now     : std_logic;

   signal posx         : std_logic_vector(15 downto 0) := (others => '0');
   signal posy         : std_logic_vector(15 downto 0) := (others => '0');

   signal move_wren    : std_logic;
   signal move_addr    : std_logic_vector( 8 downto 0) := (others => '0');
   signal move_data    : std_logic_vector(15 downto 0) := (others => '0');


   -- State machine to control the CPU
   type t_fsm_state is (FSM_INIT, FSM_IDLE, FSM_MOVE_X, FSM_MOVE_Y);
   signal fsm_state : t_fsm_state := FSM_INIT;


   type t_config is record
      addr : std_logic_vector( 8 downto 0);
      data : std_logic_vector(15 downto 0);
   end record t_config;

   type t_config_vector is array (natural range <>) of t_config;

   constant C_CONFIG : t_config_vector := (
      -- Sprite 0
      ("0" & X"00", X"0000"),
      ("0" & X"01", X"0000"),
      ("0" & X"02", X"0180"),
      ("0" & X"03", X"0660"),
      ("0" & X"04", X"0810"),
      ("0" & X"05", X"1008"),
      ("0" & X"06", X"1008"),
      ("0" & X"07", X"2004"),
      ("0" & X"08", X"2004"),
      ("0" & X"09", X"1008"),
      ("0" & X"0A", X"1008"),
      ("0" & X"0B", X"0810"),
      ("0" & X"0C", X"0660"),
      ("0" & X"0D", X"0180"),
      ("0" & X"0E", X"0000"),
      ("0" & X"0F", X"0000"),

      ("1" & X"00", X"0020"),   -- X position bits 8-0
      ("1" & X"01", X"0000"),   -- Y position
      ("1" & X"02", X"00F0"),   -- Color
      ("1" & X"03", X"0001"),   -- Enable

      -- Sprite 1
      ("0" & X"10", X"FFFF"),
      ("0" & X"11", X"8001"),
      ("0" & X"12", X"8001"),
      ("0" & X"13", X"8001"),
      ("0" & X"14", X"8001"),
      ("0" & X"15", X"8001"),
      ("0" & X"16", X"8001"),
      ("0" & X"17", X"8001"),
      ("0" & X"18", X"8001"),
      ("0" & X"19", X"8001"),
      ("0" & X"1A", X"8001"),
      ("0" & X"1B", X"8001"),
      ("0" & X"1C", X"8001"),
      ("0" & X"1D", X"8001"),
      ("0" & X"1E", X"8001"),
      ("0" & X"1F", X"FFFF"),

      ("1" & X"04", X"0023"),   -- X position bits 8-0
      ("1" & X"05", X"0000"),   -- Y position
      ("1" & X"06", X"00AA"),   -- Color
      ("1" & X"07", X"0001")    -- Enable
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
               move_addr <= "100000000";
               move_data(15 downto 8) <= X"00";
               move_data(7 downto 0)  <= posx(15 downto 8) + X"80";
               move_wren <= '1';
               fsm_state <= FSM_MOVE_Y;

            when FSM_MOVE_Y =>
               move_addr <= "100000001";
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
            wren_o <= init_wren;
            addr_o <= init_addr;
            data_o <= init_data;
         else
            wren_o <= move_wren;
            addr_o <= move_addr;
            data_o <= move_data;
         end if;
      end if;
   end process p_out;

end architecture Structural;

