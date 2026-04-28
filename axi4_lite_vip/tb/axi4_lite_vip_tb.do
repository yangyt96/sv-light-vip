onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /axi4_lite_vip_tb/axi_if/ADDR_WIDTH
add wave -noupdate /axi4_lite_vip_tb/axi_if/DATA_WIDTH
add wave -noupdate /axi4_lite_vip_tb/axi_if/STRB_WIDTH
add wave -noupdate /axi4_lite_vip_tb/axi_if/aclk
add wave -noupdate /axi4_lite_vip_tb/axi_if/aresetn
add wave -noupdate -color Gold /axi4_lite_vip_tb/axi_if/awaddr
add wave -noupdate -color Gold /axi4_lite_vip_tb/axi_if/awprot
add wave -noupdate -color Gold /axi4_lite_vip_tb/axi_if/awvalid
add wave -noupdate -color Gold /axi4_lite_vip_tb/axi_if/awready
add wave -noupdate -color {Orange Red} /axi4_lite_vip_tb/axi_if/wdata
add wave -noupdate -color {Orange Red} /axi4_lite_vip_tb/axi_if/wstrb
add wave -noupdate -color {Orange Red} /axi4_lite_vip_tb/axi_if/wvalid
add wave -noupdate -color {Orange Red} /axi4_lite_vip_tb/axi_if/wready
add wave -noupdate -color {Medium Spring Green} /axi4_lite_vip_tb/axi_if/bresp
add wave -noupdate -color {Medium Spring Green} /axi4_lite_vip_tb/axi_if/bvalid
add wave -noupdate -color {Medium Spring Green} /axi4_lite_vip_tb/axi_if/bready
add wave -noupdate -color Salmon /axi4_lite_vip_tb/axi_if/araddr
add wave -noupdate -color Salmon /axi4_lite_vip_tb/axi_if/arprot
add wave -noupdate -color Salmon /axi4_lite_vip_tb/axi_if/arvalid
add wave -noupdate -color Salmon /axi4_lite_vip_tb/axi_if/arready
add wave -noupdate -color {Violet Red} /axi4_lite_vip_tb/axi_if/rdata
add wave -noupdate -color {Violet Red} /axi4_lite_vip_tb/axi_if/rresp
add wave -noupdate -color {Violet Red} /axi4_lite_vip_tb/axi_if/rvalid
add wave -noupdate -color {Violet Red} /axi4_lite_vip_tb/axi_if/rready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1705730 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 497
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {0 ps} {7897138 ps}
