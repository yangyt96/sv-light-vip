// AXI Stream Master Environment
// Top-level verification environment for AXI Stream Master VIP
`ifndef AXIS_MASTER_ENV_SV
`define AXIS_MASTER_ENV_SV

class axis_master_env extends uvm_env;

    `uvm_component_utils(axis_master_env)

    // Agent
    axis_master_agent agent;

    // Virtual interface
    virtual axis_master_interface vif;

    function new(string name = "axis_master_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get virtual interface
        if (!uvm_config_db #(virtual axis_master_interface)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", $sformatf("Virtual interface not found for %s", get_full_name()))
        end
        
        // Propagate virtual interface to agent
        uvm_config_db #(virtual axis_master_interface)::set(this, "agent", "vif", vif);
        
        // Create agent
        agent = axis_master_agent::type_id::create("agent", this);
        
        `uvm_info("ENV_BUILD", "Environment built successfully", UVM_MEDIUM)
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("ENV_CONNECT", "Environment connected successfully", UVM_MEDIUM)
    endfunction : connect_phase

endclass : axis_master_env

`endif // AXIS_MASTER_ENV_SV
