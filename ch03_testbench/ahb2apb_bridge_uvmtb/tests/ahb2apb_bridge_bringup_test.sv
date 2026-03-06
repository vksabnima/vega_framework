// =============================================================================
// File        : ahb2apb_bridge_bringup_test.sv
// Description : Bringup Test — Infrastructure Validation
//
// Purpose:
//   Drive ONE transaction through the bridge.  No scoreboard checks.
//   If this test passes, the testbench infrastructure (interfaces, config_db,
//   agent instantiation, driver/sequencer connections, clock, reset) is working.
//   If it fails, the problem is in the TB, not the DUT.
//
// Pass criteria:
//   - Simulation completes without UVM_FATAL or UVM_ERROR
//   - No timeout
//
// Derivation:
//   - Manifest: pass_criteria.max_uvm_errors=0, max_uvm_fatals=0
//   - Intent: bringup test is explicitly a single-transaction smoke test
//
// Confidence: HIGH — simple test, minimal moving parts.
// =============================================================================

class ahb2apb_bridge_bringup_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_bringup_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config, disable scoreboard, build environment
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns = 1;              // Bringup: single transaction
    cfg.scoreboard_enable = 0;     // No scoreboard in bringup
    cfg.ahb_mst_is_active = UVM_ACTIVE;
    cfg.apb_slv_is_active = UVM_ACTIVE;

    // Publish config to all children via config_db
    // Per [U2]: use null scope, not this
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Create environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  // =========================================================================
  // end_of_elaboration_phase: disable scoreboard
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    // Disable scoreboard for bringup
    env.scb.enable = 0;
    `uvm_info("BRINGUP", "Scoreboard DISABLED for bringup test", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: drive one transaction, then finish
  //
  // Per [U6]: objections raised/dropped ONLY in base_test run_phase.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_bringup_seq ahb_seq;

    phase.raise_objection(this, "bringup_test: starting");

    `uvm_info("BRINGUP", "=== BRINGUP TEST START ===", UVM_NONE)

    // Wait for reset deassertion + a few clocks for bridge to initialize
    // Reset is asserted for 100ns per manifest, period=10ns
    #150;  // 15 clock cycles — well past reset release

    // Create and start AHB master sequence (1 transaction)
    ahb_seq = ahb_mst_bringup_seq::type_id::create("ahb_seq");
    ahb_seq.num_txns = 1;
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time from manifest: 200ns
    #200;

    `uvm_info("BRINGUP", "=== BRINGUP TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "bringup_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED based on UVM error count
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("BRINGUP", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("BRINGUP", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass