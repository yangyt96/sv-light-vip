// AXI Stream Master Driver
// Drives the AXI Stream master interface with sequence items
`ifndef AXIS_MASTER_DRIVER_SV
`define AXIS_MASTER_DRIVER_SV

class axis_master_driver extends uvm_driver #(axis_master_seq_item);

    `uvm_component_utils(axis_master_driver)

    // Virtual interface
    virtual axis_master_interface vif;

    // Configuration
    bit enable_protocol_check = 1;
    
    // Statistics
    int unsigned transfer_count = 0;

    function new(string name = "axis_master_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get the virtual interface from config database
        if (!uvm_config_db #(virtual axis_master_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", $sformatf("Virtual interface not found for %s", get_full_name()))
        end
        
        `uvm_info("DRIVER_BUILD", "Driver built successfully", UVM_MEDIUM)
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("DRIVER_CONNECT", "Driver connected successfully", UVM_MEDIUM)
    endfunction : connect_phase

    task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
    endtask : reset_phase

    // Reset interface signals to default state in post_reset phase
    task post_reset_phase(uvm_phase phase);
        super.post_reset_phase(phase);
        vif.master.tdata <= 0;
        vif.master.tvalid <= 0;
        vif.master.tstrb <= '1;
        vif.master.tkeep <= '1;
        vif.master.tlast <= 0;
        vif.master.tuser <= 0;
        vif.master.tid <= 0;
        vif.master.tdest <= 0;
        
        // Wait for a clock cycle after reset
        @(posedge vif.clk);
        
        `uvm_info("DRIVER", "Interface reset complete", UVM_HIGH)
    endtask : post_reset_phase

    task run_phase(uvm_phase phase);
        axis_master_seq_item req;
        
        `uvm_info("DRIVER", "Starting driver run phase", UVM_MEDIUM)
        
        forever begin
            seq_item_port.get_next_item(req);
            
            `uvm_info("DRIVER", $sformatf("Driving transaction: %s", req.convert2string()), UVM_HIGH)
            
            // Drive the transaction
            drive_transaction(req);

            seq_item_port.item_done();
            transfer_count++;
        end
    endtask : run_phase

    // Drive a single transaction
    task drive_transaction(axis_master_seq_item req);
        int ready_wait_count = 0;
        
        // Wait for initial delay
        repeat(req.delay) @(posedge vif.clk);
        
        // Apply data and control signals
        vif.master.tdata  <= req.tdata;
        vif.master.tstrb  <= req.tstrb;
        vif.master.tkeep  <= req.tkeep;
        vif.master.tlast  <= req.tlast;
        vif.master.tuser  <= req.tuser;
        vif.master.tid    <= req.tid;
        vif.master.tdest  <= req.tdest;
        vif.master.tvalid <= 1;
        
        // Wait for slave to accept
        @(posedge vif.clk);
        while (!vif.tready && ready_wait_count < req.ready_timeout) begin
            @(posedge vif.clk);
            ready_wait_count++;
        end
        
        if (ready_wait_count >= req.ready_timeout) begin
            `uvm_warning("DRIVER", $sformatf("tready timeout after %0d cycles", ready_wait_count))
        end
        
        // Deassert on the same cycle after the handshake completes to avoid
        // holding tvalid high for an extra transfer when tready is always asserted.
        vif.master.tvalid <= 0;
        vif.master.tdata  <= 0;
        vif.master.tstrb  <= '1;
        vif.master.tkeep  <= '1;
        vif.master.tlast  <= 0;
        vif.master.tuser  <= 0;
        
    endtask : drive_transaction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("DRIVER", $sformatf("Transfers driven: %0d", transfer_count), UVM_LOW)
    endfunction : report_phase

endclass : axis_master_driver

`endif // AXIS_MASTER_DRIVER_SV
