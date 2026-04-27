// apb_vip_pkg
// Software class-based VIP components (master, slave).
// NOTE: apb_mem_vip is a hardware module, NOT a class.
// It must be `included and instantiated directly in the testbench.
// See: apb_mem_vip.sv

package apb_vip_pkg;

  `include "apb_master_vip.sv"
  `include "apb_slave_vip.sv"

endpackage
