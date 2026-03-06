// =============================================================================
// File        : ahb2apb_bridge_dut_config.sv
// Description : DUT-level configuration object
//
// Centralises all configuration knobs for the testbench:
//   - Number of transactions (from manifest stimulus.num_txns = 5)
//   - Address range (from IP-XACT APB_ADDR_START/END)
//   - Agent activity modes
//
// Derivation:
//   - Manifest: stimulus.num_txns=5, drain_time_ns=200
//   - IP-XACT:  APB_ADDR_START=0, APB_ADDR_END=65535 (0xFFFF),
//               REG_BASE=3840 (0x0F00)
//
// Confidence: HIGH — straightforward configuration container.
// =============================================================================

class ahb2apb_bridge_dut_config extends uvm_object;
  `uvm_object_utils(ahb2apb_bridge_dut_config)

  // ----- Transaction count -----
  // From manifest: stimulus.num_txns = 5
  int num_txns = 5;

  // ----- Address ranges (from IP-XACT parameters) -----
  // APB window: 0x0000_0000 to 0x0000_FFFF
  // Register block: 0x0000_0F00 to 0x0000_0F0F (16 bytes)
  // For bringup/sanity: avoid register range to test pure bridge path
  bit [31:0] apb_addr_start = 32'h0000_0000;
  bit [31:0] apb_addr_end   = 32'h0000_FFFF;
  bit [31:0] reg_base       = 32'h0000_0F00;
  bit [31:0] reg_end        = 32'h0000_0F0F;

  // ----- Agent modes -----
  // ahb_mst is ACTIVE (drives AHB), apb_slv is ACTIVE (reactive slave)
  uvm_active_passive_enum ahb_mst_is_active = UVM_ACTIVE;
  uvm_active_passive_enum apb_slv_is_active = UVM_ACTIVE;

  // ----- Drain time in ns -----
  int drain_time_ns = 200;

  // ----- Scoreboard enable (disabled for bringup test) -----
  bit scoreboard_enable = 1;

  function new(string name = "ahb2apb_bridge_dut_config");
    super.new(name);
  endfunction

endclass