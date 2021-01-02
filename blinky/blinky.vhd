library ieee;
use ieee.std_logic_1164.all;

entity top is
   port (
      clk_i : in  std_logic;
      sw    : in  std_logic_vector(3 downto 0);
      led   : out std_logic_vector(11 downto 0)
   );
end entity top;

architecture synthesis of top is
begin
   led <= sw & sw & sw;
end architecture synthesis;

--module top (input clk_i, input [3:0] sw, output [11:0] led);
--
--    //assign led = {&sw, |sw, ^sw, ~^sw};
--
--    wire clk;
--    BUFGCTRL bufg_i (
--        .I0(clk_i),
--        .CE0(1'b1),
--        .S0(1'b1),
--        .O(clk)
--    );
--
--
--  //  wire clk = clk_i;
--
--    reg clkdiv;
--    reg [22:0] ctr;
--
--    always @(posedge clk) {clkdiv, ctr} <= ctr + 1'b1;
--
--    reg [5:0] led_r = 4'b0000;
--
--    always @(posedge clk) begin
--        if (clkdiv)
--            led_r <= led_r + 1'b1;
--    end
--
--    wire [11:0] led_s = led_r[3:0] << (4 * led_r[5:4]);
--
--    assign led = &(led_r[5:4]) ? {3{led_r[3:0]}} : led_s;
--
--endmodule
