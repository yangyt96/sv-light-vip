// AXI Stream Master Sequences
// Defines various stimulus patterns for testing
`ifndef AXIS_MASTER_SEQUENCES_SV
`define AXIS_MASTER_SEQUENCES_SV

// Base sequence class
class axis_master_base_seq extends uvm_sequence #(axis_master_seq_item);

    `uvm_object_utils(axis_master_base_seq)

    int unsigned num_items = 10;

    function new(string name = "axis_master_base_seq");
        super.new(name);
    endfunction : new

endclass : axis_master_base_seq

// Simple random sequence
class axis_master_random_seq extends axis_master_base_seq;

    `uvm_object_utils(axis_master_random_seq)

    function new(string name = "axis_master_random_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        axis_master_seq_item item;
        bit [`AXIS_DATA_WIDTH-1:0] random_data;
        bit [`AXIS_DATA_WIDTH/8-1:0] full_mask;
        
        `uvm_info("SEQ", $sformatf("Starting random sequence with %0d items", num_items), UVM_MEDIUM)

        full_mask = '1;
        
        repeat(num_items) begin
            item = axis_master_seq_item::type_id::create("item");
            start_item(item);

            random_data = $urandom();
            item.tdata = random_data;
            item.tlast = $urandom_range(0, 1);
            item.tstrb = full_mask;
            item.tkeep = full_mask;
            item.tuser = $urandom_range(0, 15);
            item.tid = 0;
            item.tdest = 0;
            item.delay = $urandom_range(0, 10);

            finish_item(item);
        end
        
        `uvm_info("SEQ", "Random sequence completed", UVM_MEDIUM)
    endtask : body

endclass : axis_master_random_seq

// Sequence for continuous burst transfers
class axis_master_burst_seq extends axis_master_base_seq;

    `uvm_object_utils(axis_master_burst_seq)

    int unsigned burst_length = 16;

    function new(string name = "axis_master_burst_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        axis_master_seq_item item;
        int xfer_count = 0;
        bit [`AXIS_DATA_WIDTH-1:0] random_data;
        bit [`AXIS_DATA_WIDTH/8-1:0] full_mask;
        
        `uvm_info("SEQ", $sformatf("Starting burst sequence: num_items=%0d, burst_length=%0d", num_items, burst_length), UVM_MEDIUM)

        full_mask = '1;
        
        repeat(num_items) begin
            repeat(burst_length) begin
                item = axis_master_seq_item::type_id::create("item");
                start_item(item);

                random_data = $urandom();
                item.tdata = random_data;
                item.tstrb = full_mask;
                item.tkeep = full_mask;
                item.tuser = $urandom_range(0, 15);
                item.tid = 0;
                item.tdest = 0;
                item.delay = $urandom_range(0, 10);
                
                // Set tlast on last transfer of burst
                if (xfer_count == burst_length - 1) begin
                    item.tlast = 1;
                    xfer_count = 0;
                end else begin
                    item.tlast = 0;
                    xfer_count++;
                end
                
                finish_item(item);
            end
        end
        
        `uvm_info("SEQ", "Burst sequence completed", UVM_MEDIUM)
    endtask : body

endclass : axis_master_burst_seq

// Fixed pattern sequence
class axis_master_fixed_pattern_seq extends axis_master_base_seq;

    `uvm_object_utils(axis_master_fixed_pattern_seq)

    bit [127:0] pattern = 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;  // Alternating bits

    function new(string name = "axis_master_fixed_pattern_seq");
        super.new(name);
    endfunction : new

    virtual task body();
        axis_master_seq_item item;
        bit [127:0] data = pattern;
        bit [`AXIS_DATA_WIDTH-1:0] masked_data;
        
        `uvm_info("SEQ", $sformatf("Starting fixed pattern sequence: pattern=0x%h", pattern), UVM_MEDIUM)
        
        repeat(num_items) begin
            item = axis_master_seq_item::type_id::create("item");
            start_item(item);
            // Mask the data to match AXIS_DATA_WIDTH
            masked_data = data[`AXIS_DATA_WIDTH-1:0];
            item.tdata = masked_data;
            item.delay = 0;
            finish_item(item);
            
            // Rotate pattern
            data = {data[0], data[127:1]};
        end
        
        `uvm_info("SEQ", "Fixed pattern sequence completed", UVM_MEDIUM)
    endtask : body

endclass : axis_master_fixed_pattern_seq

`endif // AXIS_MASTER_SEQUENCES_SV
