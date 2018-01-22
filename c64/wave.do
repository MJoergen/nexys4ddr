onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/clk_i
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/rst_i
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/addr_o
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/rden_o
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/data_i
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/wren_o
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/data_o
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/irq_i
add wave -noupdate -expand -group CPU /hack_tb/inst_hack/inst_cpu/debug_o
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/alu_out
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/alu_c
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/alu_s
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/alu_v
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/alu_z
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/reg_sp
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/reg_pc
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/reg_sr
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/regs_rd_data
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/regs_debug
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/mem_addr_reg
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/irq_masked
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_reg
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_pc
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_sp
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_hold_addr
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_szcv
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_b
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_i
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_d
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_wr_sr
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_mem_addr
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_mem_rden
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_reg_nr
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_mem_wrdata
add wave -noupdate -expand -group CPU -group Internal /hack_tb/inst_hack/inst_cpu/ctl_debug
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {99999982030 fs} 0}
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
WaveRestoreZoom {0 fs} {105 us}
