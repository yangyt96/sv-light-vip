onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/ADDR_WIDTH
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/DATA_WIDTH
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/STRB_WIDTH
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/aclk
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/aresetn
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/awaddr
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/awprot
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/awvalid
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/awready
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/wdata
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/wstrb
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/wvalid
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/wready
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/bresp
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/bvalid
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/bready
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/araddr
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/arprot
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/arvalid
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/arready
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/rdata
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/rresp
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/rvalid
add wave -noupdate -group s_axil_if /axi4_lite_dut_tb/s_axil_if/rready
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/ADDR_WIDTH
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/DATA_WIDTH
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/STRB_WIDTH
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/aclk
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/aresetn
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/awaddr
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/awprot
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/awvalid
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/awready
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/wdata
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/wstrb
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/wvalid
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/wready
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/bresp
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/bvalid
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/bready
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/araddr
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/arprot
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/arvalid
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/arready
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/rdata
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/rresp
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/rvalid
add wave -noupdate -expand -group m_axil_if /axi4_lite_dut_tb/m_axil_if/rready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
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
