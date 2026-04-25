onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /i2c_vip_tb/HALF_SCL_CYCLES
add wave -noupdate /i2c_vip_tb/STIMULUS_COUNT
add wave -noupdate /i2c_vip_tb/CONTINUOUS_TRANSFER_COUNT
add wave -noupdate /i2c_vip_tb/SLAVE_ADDRESS
add wave -noupdate /i2c_vip_tb/INTER_TRANSACTION_PAUSE
add wave -noupdate /i2c_vip_tb/clk
add wave -noupdate /i2c_vip_tb/rstn
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/clk
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/rstn
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/scl
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/sda
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/master_scl_low
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/master_sda_low
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/slave_scl_low
add wave -noupdate -group i2c_link /i2c_vip_tb/i2c_link/slave_sda_low
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 180
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
