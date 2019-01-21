module vga (
   clk100_i,
   vga_hs_o,
   vga_vs_o,
   vga_col_o
);

input          clk100_i;
output         vga_hs_o;
output         vga_vs_o;
output [7:0]   vga_col_o;

wire           vga_clk;

reg [1:0]      clk_cnt   = 0;
reg [9:0]      vga_pix_x = 0;
reg [9:0]      vga_pix_y = 0;
reg            vga_hs;
reg            vga_vs;
reg [7:0]      vga_col;

localparam     VGA_X_SIZE   = 800;
localparam     VGA_Y_SIZE   = 525;
localparam     VGA_HS_BEGIN = 656;
localparam     VGA_HS_SIZE  =  96;
localparam     VGA_VS_BEGIN = 490;
localparam     VGA_VS_SIZE  =   2;
localparam     VGA_X_PIXELS = 640;
localparam     VGA_Y_PIXELS = 480;

always @ (posedge clk100_i)
begin
   clk_cnt <= clk_cnt + 1;
end

assign vga_clk = clk_cnt[1];

always @ (posedge vga_clk)
begin
   if (vga_pix_x == VGA_X_SIZE-1) begin
      vga_pix_x <= 0;
   end else begin
      vga_pix_x <= vga_pix_x + 1;
   end
end

always @ (posedge vga_clk)
begin
   if (vga_pix_x == VGA_X_SIZE-1) begin
      if (vga_pix_y == VGA_Y_SIZE-1) begin
         vga_pix_y <= 0;
      end else begin
         vga_pix_y <= vga_pix_y + 1;
      end
   end
end

always @ (posedge vga_clk)
begin
   vga_hs <= 1'b0;
   if (vga_pix_x >= VGA_HS_BEGIN && vga_pix_x < VGA_HS_BEGIN + VGA_HS_SIZE) begin
      vga_hs <= 1'b1;
   end

   vga_vs <= 1'b0;
   if (vga_pix_y >= VGA_VS_BEGIN && vga_pix_y < VGA_VS_BEGIN + VGA_VS_SIZE) begin
      vga_vs <= 1'b1;
   end

   vga_col <= 0;
   if (vga_pix_x < VGA_X_PIXELS && vga_pix_y < VGA_Y_PIXELS) begin
      vga_col <= vga_pix_x[8:1] ^ vga_pix_y[8:1];
   end
end

assign vga_hs_o  = vga_hs;
assign vga_vs_o  = vga_vs;
assign vga_col_o = vga_col;

endmodule

module vga_tb;

reg          clk100 = 0;
wire         vga_hs;
wire         vga_vs;
wire [7:0]   vga_col;

always begin
   #20 clk100 = !clk100;
end

vga DUT (
   .clk100_i  (clk100),
   .vga_hs_o  (vga_hs),
   .vga_vs_o  (vga_vs),
   .vga_col_o (vga_col)
);

endmodule

