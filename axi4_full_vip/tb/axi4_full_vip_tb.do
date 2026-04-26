onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /axi4_full_vip_tb/mem_vip/ADDR_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/DATA_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/ID_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/LEN_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/SIZE_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/BURST_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/LOCK_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/CACHE_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/PROT_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/QOS_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/REGION_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/STRB_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/AWUSER_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/WUSER_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/BUSER_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/ARUSER_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/RUSER_WIDTH
add wave -noupdate /axi4_full_vip_tb/mem_vip/MEM_BYTES
add wave -noupdate /axi4_full_vip_tb/mem_vip/AXI_RESP_OKAY
add wave -noupdate /axi4_full_vip_tb/mem_vip/AXI_BURST_FIXED
add wave -noupdate /axi4_full_vip_tb/mem_vip/AXI_BURST_INCR
add wave -noupdate /axi4_full_vip_tb/mem_vip/AXI_BURST_WRAP
add wave -noupdate /axi4_full_vip_tb/mem_vip/aclk
add wave -noupdate /axi4_full_vip_tb/mem_vip/aresetn
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awid
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awaddr
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awlen
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awsize
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awburst
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awlock
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awcache
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awprot
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awqos
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awregion
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awuser
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awvalid
add wave -noupdate -color {Medium Spring Green} /axi4_full_vip_tb/mem_vip/s_axi_awready
add wave -noupdate -color Gold /axi4_full_vip_tb/mem_vip/s_axi_wdata
add wave -noupdate -color Gold /axi4_full_vip_tb/mem_vip/s_axi_wstrb
add wave -noupdate -color Gold /axi4_full_vip_tb/mem_vip/s_axi_wlast
add wave -noupdate -color Gold /axi4_full_vip_tb/mem_vip/s_axi_wuser
add wave -noupdate -color Gold /axi4_full_vip_tb/mem_vip/s_axi_wvalid
add wave -noupdate -color Gold /axi4_full_vip_tb/mem_vip/s_axi_wready
add wave -noupdate -color Pink /axi4_full_vip_tb/mem_vip/s_axi_bid
add wave -noupdate -color Pink /axi4_full_vip_tb/mem_vip/s_axi_bresp
add wave -noupdate -color Pink /axi4_full_vip_tb/mem_vip/s_axi_buser
add wave -noupdate -color Pink /axi4_full_vip_tb/mem_vip/s_axi_bvalid
add wave -noupdate -color Pink /axi4_full_vip_tb/mem_vip/s_axi_bready
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arid
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_araddr
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arlen
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arsize
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arburst
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arlock
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arcache
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arprot
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arqos
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arregion
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_aruser
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arvalid
add wave -noupdate -color {Orange Red} /axi4_full_vip_tb/mem_vip/s_axi_arready
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_rid
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_rdata
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_rresp
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_rlast
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_ruser
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_rvalid
add wave -noupdate -color Magenta /axi4_full_vip_tb/mem_vip/s_axi_rready
add wave -noupdate /axi4_full_vip_tb/mem_vip/mem
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_id
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_addr
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_size
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_burst
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_beats_total
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_beat_count
add wave -noupdate -color Orchid /axi4_full_vip_tb/mem_vip/wr_active
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_id
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_addr
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_size
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_burst
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_beats_total
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_beat_count
add wave -noupdate -color {Lime Green} /axi4_full_vip_tb/mem_vip/rd_active
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {255000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 525
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
WaveRestoreZoom {0 ps} {863774 ps}
