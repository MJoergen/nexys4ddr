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
      cs_o   : out std_logic;
      wren_o : out std_logic;
      addr_o : out std_logic_vector(8 downto 0);
      data_o : out std_logic_vector(7 downto 0)
   );

end entity config;

architecture Structural of config is

   function get_counter_size (simulation : string) return integer
   is
   begin
      if simulation = "yes" then
         return 5;
      else
         return 10000000;  -- 100 Mhz / 10 millioner = 10 pixels / sec.
      end if;

   end function;

   constant C_COUNT_MAX : integer := get_counter_size(G_SIMULATION);

   signal init_cs      : std_logic;
   signal init_wren    : std_logic;
   signal init_addr    : std_logic_vector(8 downto 0);
   signal init_data    : std_logic_vector(7 downto 0);
   signal init_counter : integer := 0;

   signal move_counter : integer range 0 to C_COUNT_MAX := 0;
   signal move_now     : std_logic;

   signal dirx         : integer range -1 to 1 := 1;
   signal diry         : integer range -1 to 1 := 1;

   signal posx         : std_logic_vector(8 downto 0) := (others => '0');
   signal posy         : std_logic_vector(7 downto 0) := (others => '0');

   signal move_cs      : std_logic;
   signal move_wren    : std_logic;
   signal move_addr    : std_logic_vector(8 downto 0) := (others => '0');
   signal move_data    : std_logic_vector(7 downto 0) := (others => '0');


   -- State machine to control the CPU
   type t_fsm_state is (FSM_INIT, FSM_IDLE, FSM_MOVE_X, FSM_MOVE_MSB, FSM_MOVE_Y);
   signal fsm_state : t_fsm_state := FSM_INIT;


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

   p_init : process (clk_i)
   begin
      if rising_edge(clk_i) then
         init_cs   <= '0';
         init_wren <= '0';

         if init_counter < C_CONFIG'length then
            init_addr <= C_CONFIG(init_counter).addr;
            init_data <= C_CONFIG(init_counter).data;
            init_cs   <= '1';
            init_wren <= '1';
            init_counter <= init_counter + 1;
         end if;

         if rst_i = '1' then
            init_cs   <= '0';
            init_wren <= '0';
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


   p_dir : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if move_now = '1' then
            if dirx = 1 and posx = 320-24 then
               dirx <= -1;
            end if;

            if dirx = -1 and posx = 0 then
               dirx <= 1;
            end if;

            if diry = 1 and posy = 240-21 then
               diry <= -1;
            end if;

            if diry = -1 and posy = 0 then
               diry <= 1;
            end if;
         end if;
      end if;
   end process p_dir;


   p_pos : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if move_now = '1' then
            posx <= posx + dirx;
            posy <= posy + diry;
         end if;
      end if;
   end process p_pos;

   
   p_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         move_cs   <= '0';
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
               move_data <= posx(7 downto 0);
               move_cs   <= '1';
               move_wren <= '1';
               fsm_state <= FSM_MOVE_MSB;

            when FSM_MOVE_MSB =>
               move_addr <= "100000001";
               move_data <= "0000000" & posx(8);
               move_cs   <= '1';
               move_wren <= '1';
               fsm_state <= FSM_MOVE_Y;

            when FSM_MOVE_Y =>
               move_addr <= "100000010";
               move_data <= posy;
               move_cs   <= '1';
               move_wren <= '1';
               fsm_state <= FSM_IDLE;

            when others =>
               fsm_state <= FSM_IDLE;
         end case;
      end if;
   end process p_fsm;


   -----------------------
   -- Drive output signals
   -----------------------

   cs_o   <= init_cs when fsm_state = FSM_INIT else move_cs;
   wren_o <= init_wren when fsm_state = FSM_INIT else move_wren;
   addr_o <= init_addr when fsm_state = FSM_INIT else move_addr;
   data_o <= init_data when fsm_state = FSM_INIT else move_data;

end architecture Structural;

