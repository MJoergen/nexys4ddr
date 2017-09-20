library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity counter is

    generic (
        FREQ       : integer
        );
    port (
        -- Clock, reset, and enable
        rst_i      : in  std_logic;
        clk_i      : in  std_logic;
        speed_i    : in  std_logic_vector(7 downto 1);
        en_o       : out std_logic
        );

end counter;

architecture Structural of counter is

    signal count   : integer range 0 to FREQ;

begin

    -- This generates the steps of the game.
    gen_counter : process (rst_i, clk_i)
    begin
        if rst_i = '1' then
            en_o <= '0';
            count <= 0;
        elsif rising_edge(clk_i) then
            en_o <= '0';
            if count < freq then
                count <= count + conv_integer(speed_i);
            else
                count <= 0;
                en_o <= '1';
            end if;
        end if;
    end process gen_counter;
  
end Structural;

