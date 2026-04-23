// AXI Stream Master Agent
// Integrates driver, sequencer, and monitor
`ifndef AXIS_MASTER_AGENT_SV
`define AXIS_MASTER_AGENT_SV

class axis_master_agent extends uvm_agent;

    `uvm_component_utils(axis_master_agent)

    // Components
    axis_master_driver      driver;
    axis_master_sequencer   sequencer;
    axis_master_monitor     monitor;

    // Virtual interface
    virtual axis_master_interface vif;

    // Configuration
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "axis_master_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Set config for is_active
        uvm_config_db #(uvm_active_passive_enum)::set(this, "*", "is_active", is_active);
        
        // Get virtual interface
        if (!uvm_config_db #(virtual axis_master_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", $sformatf("Virtual interface not found for %s", get_full_name()))
        end
        
        // Propagate virtual interface to child components
        uvm_config_db #(virtual axis_master_interface)::set(this, "driver", "vif", vif);
        uvm_config_db #(virtual axis_master_interface)::set(this, "monitor", "vif", vif);
        
        // Create components
        monitor = axis_master_monitor::type_id::create("monitor", this);
        
        if (is_active == UVM_ACTIVE) begin
            driver = axis_master_driver::type_id::create("driver", this);
            sequencer = axis_master_sequencer::type_id::create("sequencer", this);
        end
        
        `uvm_info("AGENT_BUILD", "Agent built successfully", UVM_MEDIUM)
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
        
        `uvm_info("AGENT_CONNECT", "Agent connected successfully", UVM_MEDIUM)
    endfunction : connect_phase

endclass : axis_master_agent

`endif // AXIS_MASTER_AGENT_SV
