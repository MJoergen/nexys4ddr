onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group vga /tb/i_top/i_vga/clk_i
add wave -noupdate -expand -group vga /tb/i_top/i_vga/hex_i
add wave -noupdate -expand -group vga /tb/i_top/i_vga/vga_hs_o
add wave -noupdate -expand -group vga /tb/i_top/i_vga/vga_vs_o
add wave -noupdate -expand -group vga /tb/i_top/i_vga/vga_col_o
add wave -noupdate -expand -group vga /tb/i_top/i_vga/pix_x
add wave -noupdate -expand -group vga /tb/i_top/i_vga/pix_y
add wave -noupdate -expand -group vga /tb/i_top/i_vga/stage1
add wave -noupdate -expand -group vga /tb/i_top/i_vga/stage2
add wave -noupdate -expand -group vga -expand /tb/i_top/i_vga/stage3
add wave -noupdate -expand -group rom /tb/i_top/i_vga/i_rom/clk_i
add wave -noupdate -expand -group rom /tb/i_top/i_vga/i_rom/addr_i
add wave -noupdate -expand -group rom /tb/i_top/i_vga/i_rom/data_o
add wave -noupdate -expand -group rom /tb/i_top/i_vga/i_rom/data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {420000000 fs} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 fs} {105211735904 fs}
