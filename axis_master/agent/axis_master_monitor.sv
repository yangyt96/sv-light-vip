// AXI Stream Master Monitor
// Passively monitors the AXI Stream master interface
`ifndef AXIS_MASTER_MONITOR_SV
`define AXIS_MASTER_MONITOR_SV

class axis_master_monitor extends uvm_monitor;

    `uvm_component_utils(axis_master_monitor)

    // Virtual interface
    virtual axis_master_interface vif;

    // Analysis port for collected transactions
    uvm_analysis_port #(axis_master_seq_item) item_collected_port;

    // Configuration
    bit enable_coverage = 1;

    // Statistics
    int unsigned transaction_count = 0;
    int unsigned error_count = 0;

    function new(string name = "axis_master_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get virtual interface from config database
        if (!uvm_config_db #(virtual axis_master_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", $sformatf("Virtual interface not found for %s", get_full_name()))
        end
        
        `uvm_info("MONITOR_BUILD", "Monitor built successfully", UVM_MEDIUM)
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        axis_master_seq_item item;
        
        `uvm_info("MONITOR", "Starting monitor run phase", UVM_MEDIUM)
        
        forever begin
            @(posedge vif.clk);
            
            // Check for valid transfer
            if (vif.tvalid && vif.tready) begin
                // Collect the transfer
                item = axis_master_seq_item::type_id::create("item");
                item.tdata = vif.tdata;
                item.tlast = vif.tlast;
                item.tstrb = vif.tstrb;
                item.tkeep = vif.tkeep;
                item.tuser = vif.tuser;
                item.tid = vif.tid;
                item.tdest = vif.tdest;
                
                // Write to analysis port
                item_collected_port.write(item);
                
                transaction_count++;
                `uvm_info("MONITOR", $sformatf("Transfer collected: tdata=0x%h", item.tdata), UVM_HIGH)
            end
        end
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("MONITOR", $sformatf("Transactions monitored: %0d", transaction_count), UVM_LOW)
        if (error_count > 0) begin
            `uvm_warning("MONITOR", $sformatf("Errors detected: %0d", error_count))
        end
    endfunction : report_phase

endclass : axis_master_monitor

`endif // AXIS_MASTER_MONITOR_SV
