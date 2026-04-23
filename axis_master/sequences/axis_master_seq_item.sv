// AXI Stream Master Sequence Item
// Defines the stimulus to be driven on the AXI Stream master interface
`ifndef AXIS_MASTER_SEQ_ITEM_SV
`define AXIS_MASTER_SEQ_ITEM_SV

class axis_master_seq_item extends uvm_sequence_item;

    `uvm_object_utils(axis_master_seq_item)

    // Data payload
    rand bit [`AXIS_DATA_WIDTH-1:0] tdata;
    
    // Control signals
    rand bit                         tlast;  // Last transfer indicator
    rand bit [`AXIS_DATA_WIDTH/8-1:0] tstrb; // Byte strobes (valid bytes)
    rand bit [`AXIS_DATA_WIDTH/8-1:0] tkeep; // Byte enable
    rand bit [3:0]                   tuser;  // User-defined sideband
    
    // Optional signals (if parametrized)
    rand bit [3:0]                   tid;    // Transaction ID
    rand bit [3:0]                   tdest;  // Destination
    
    // Delay between transfers
    rand int unsigned                delay;  // Cycles to wait before asserting tvalid
    
    // Wait for ready timeout
    int unsigned                     ready_timeout = 1000;
    
    // Constraints
    constraint delay_constraint {
        delay inside {[0:10]};
    }
    
    constraint tstrb_constraint {
        if (tlast == 1) {
            tstrb != 0;  // At least one byte must be valid on last
        }
    }

    function new(string name = "axis_master_seq_item");
        super.new(name);
        tstrb = '1;  // All bytes valid by default
        tkeep = '1;
        tlast = 0;
        tuser = 0;
        tid = 0;
        tdest = 0;
        delay = 0;
    endfunction : new

    function void post_randomize();
        // Ensure tkeep is subset of tstrb
        tkeep = tkeep & tstrb;
    endfunction : post_randomize

    function string convert2string();
        string s;
        s = $sformatf("axis_master_seq_item: tdata=0x%h, tvalid=1, tready=?, tlast=%0d, tstrb=0x%h, tkeep=0x%h, tuser=0x%h, delay=%0d", 
                      tdata, tlast, tstrb, tkeep, tuser, delay);
        return s;
    endfunction : convert2string

endclass : axis_master_seq_item

`endif // AXIS_MASTER_SEQ_ITEM_SV
