// =============================================================================
// FILE: config/ahb2apb_bridge_dut_config.sv
// =============================================================================
// COMPONENT  : DUT Configuration Object
// DESCRIPTION: Centralized configuration class holding testbench parameters.
//              Passed via uvm_config_db to all agents, env, and tests.
//
// DERIVED FROM:
//   - Manifest: num_txns=5, drain_time=200ns, interfaces, parameters.
//   - IP-XACT: ADDR_WIDTH=32, DATA_WIDTH=32, APB address range.
//   - Intent: Simple memory slave, single transfers only.
//
// CONFIDENCE: HIGH — all fields map directly to manifest/IP-XACT parameters.
// =============================================================================

class ahb2apb_bridge_dut_config extends uvm_object;

  `uvm_object_utils(ahb2apb_bridge_dut_config)

  // ── Virtual interface handles ────────────────────────────────────────────
  // These are set by tb_top via config_db, retrieved by agents.
  // No modport suffix per [U1].
  virtual ahb_mst_if ahb_vif;
  virtual apb_slv_if apb_vif;

  // ── DUT Parameters (from IP-XACT and Manifest) ──────────────────────────
  int unsigned addr_width   = 32;    // IP-XACT: ADDR_WIDTH
  int unsigned data_width   = 32;    // IP-XACT: DATA_WIDTH
  bit [31:0]   apb_addr_start = 32'h0000_0000; // IP-XACT: APB_ADDR_START
  bit [31:0]   apb_addr_end   = 32'h0000_FFFF; // IP-XACT: APB_ADDR_END
  bit [31:0]   reg_base       = 32'h0000_0F00; // IP-XACT: REG_BASE

  // ── Stimulus Control (from Manifest) ─────────────────────────────────────
  int unsigned num_txns     = 5;     // Manifest: stimulus.num_txns
  int unsigned drain_time   = 200;   // Manifest: stimulus.drain_time_ns

  // ── Agent Activity Control ───────────────────────────────────────────────
  // AHB agent is active (drives stimulus), APB agent is active (reactive slave)
  uvm_active_passive_enum ahb_agent_is_active = UVM_ACTIVE;  // Manifest: role=active
  uvm_active_passive_enum apb_agent_is_active = UVM_ACTIVE;  // Manifest: role=passive but
  // EDIT_RECOMMENDED: The manifest says apb_slv role is "passive" but the verification
  // intent says "APB slave agent should behave as a simple memory slave" which requires
  // driving PRDATA/PREADY/PSLVERR. We set it to UVM_ACTIVE so the driver runs.
  // If you want a purely passive monitor-only APB agent, change to UVM_PASSIVE.

  // ── Scoreboard Enable ────────────────────────────────────────────────────
  bit scoreboard_enable = 1;  // Disabled for bringup_test, enabled for sanity_test

  // ── APB slave error injection (set by error/timeout tests) ───────────────
  // The reactive APB slave normally responds OKAY. Tests that need to exercise
  // the bridge's error-handling paths register the target addresses here:
  //   apb_err_addrs   — APB addresses where the slave returns PSLVERR=1
  //                     (provokes a peripheral/target error; bridge -> HRESP=1,
  //                      STATUS.PSLVERR sticky bit set).
  //   apb_stall_addrs — APB addresses where the slave withholds PREADY for
  //                     apb_stall_cycles, so the bridge's timeout FSM fires
  //                     (STATUS.TIMEOUT_ERR set, HRESP=1).
  bit [31:0]   apb_err_addrs[$];
  bit [31:0]   apb_stall_addrs[$];
  // Stall cap: the loop exits early when the bridge aborts (drops PSEL) on
  // timeout, so this only needs to exceed the largest timeout window
  // (TIMEOUT_VAL=7 => 2048 cycles).
  int unsigned apb_stall_cycles = 2600;

  function void add_apb_err_addr(bit [31:0] a);   apb_err_addrs.push_back(a);   endfunction
  function void add_apb_stall_addr(bit [31:0] a); apb_stall_addrs.push_back(a); endfunction

  function bit apb_is_err_addr(bit [31:0] a);
    foreach (apb_err_addrs[i]) if (apb_err_addrs[i] === a) return 1'b1;
    return 1'b0;
  endfunction

  function bit apb_is_stall_addr(bit [31:0] a);
    foreach (apb_stall_addrs[i]) if (apb_stall_addrs[i] === a) return 1'b1;
    return 1'b0;
  endfunction

  function new(string name = "ahb2apb_bridge_dut_config");
    super.new(name);
  endfunction : new

endclass : ahb2apb_bridge_dut_config