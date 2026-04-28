onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /axi4_stream_vip_tb/clk
add wave -noupdate /axi4_stream_vip_tb/rstn
add wave -noupdate /axi4_stream_vip_tb/axis_if/tvalid
add wave -noupdate /axi4_stream_vip_tb/axis_if/tready
add wave -noupdate /axi4_stream_vip_tb/axis_if/tdata
add wave -noupdate /axi4_stream_vip_tb/axis_if/tkeep
add wave -noupdate /axi4_stream_vip_tb/axis_if/tstrb
add wave -noupdate /axi4_stream_vip_tb/axis_if/tlast
add wave -noupdate /axi4_stream_vip_tb/axis_if/tid
add wave -noupdate /axi4_stream_vip_tb/axis_if/tdest
add wave -noupdate /axi4_stream_vip_tb/axis_if/tuser
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
WaveRestoreZoom {0 ps} {1 ms}
