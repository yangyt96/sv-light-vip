// axi4_lite_vip_pkg
// Software class-based VIP components (master and slave).
// NOTE: axi4_lite_mem_vip is a hardware module, NOT a class.
// It must be `included and instantiated directly in the testbench.
// See: axi4_lite_mem_vip.sv

package axi4_lite_vip_pkg;

  `include "axi4_lite_master_vip.sv"
  `include "axi4_lite_slave_vip.sv"

endpackage
