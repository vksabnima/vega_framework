// =============================================================================
// File        : ahb2apb_bridge_sanity_test.sv
// Description : Sanity Test — Full Scoreboard Verification
//
// Purpose:
//   Drive num_txns (5) transactions through the bridge with full scoreboard
//   checking.  Verifies ALL verification goals (VG1–VG6).
//   If bringup_test passes but this test fails, the DUT behavior is wrong.
//
// Pass criteria:
//   - All VG1–VG6 checks pass
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Derivation:
//   - Manifest: stimulus.num_txns=5, all verification goals
//   - Intent: full CHECK section implemented via scoreboard
//
// Confidence: HIGH — extends bringup with more transactions and scoreboard.
// =============================================================================

class ahb2apb_bridge_sanity_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_sanity_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config with full checking enabled
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns = 5;              // From manifest: stimulus.num_txns = 5
    cfg.scoreboard_enable = 1;     // Full scoreboard checking
    cfg.ahb_mst_is_active = UVM_ACTIVE;
    cfg.apb_slv_is_active = UVM_ACTIVE;

    // Per [U2]: null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  // =========================================================================
  // end_of_elaboration_phase: ensure scoreboard is enabled
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
    `uvm_info("SANITY", "Scoreboard ENABLED for sanity test", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: drive num_txns transactions with full scoreboard
  //
  // Per [U6]: objections raised/dropped only here.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_bringup_seq ahb_seq;

    phase.raise_objection(this, "sanity_test: starting");

    `uvm_info("SANITY", "=== SANITY TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Create and start AHB master sequence with 5 transactions
    ahb_seq = ahb_mst_bringup_seq::type_id::create("ahb_seq");
    ahb_seq.num_txns = cfg.num_txns;
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time: 200ns per manifest
    #(cfg.drain_time_ns);

    `uvm_info("SANITY", "=== SANITY TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "sanity_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("SANITY", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("SANITY", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass