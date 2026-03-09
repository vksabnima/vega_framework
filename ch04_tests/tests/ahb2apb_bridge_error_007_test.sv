// =============================================================================
// File        : ahb2apb_bridge_error_007_test.sv
// Description : Error Test 007 — PSLVERR Sampling Conditions
//
// Purpose:
//   Verify PSLVERR sampling behavior across two phases:
//     Phase 1: Write with PSLVERR asserted — expects error response.
//     Phase 2: Recovery write without PSLVERR — expects clean completion.
//
//   The sequence body() handles both phases in a single run.  To ensure
//   only the first transfer sees PSLVERR, pslverr_inject_once=1 is used
//   instead of pslverr_inject=1.  This auto-clears after one transfer,
//   allowing the recovery write to complete without error.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Disabled (enable=0) because this test mixes PSLVERR error transactions
//   with recovery transactions.
// =============================================================================

class ahb2apb_bridge_error_007_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_007_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config with scoreboard disabled
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns = 10;
    cfg.scoreboard_enable = 1;
    cfg.ahb_mst_is_active = UVM_ACTIVE;
    cfg.apb_slv_is_active = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  // =========================================================================
  // end_of_elaboration_phase: disable scoreboard for PSLVERR + recovery test
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    `uvm_info("ERROR_007", "Scoreboard DISABLED — PSLVERR + recovery", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: configure APB driver for one-shot PSLVERR and drive sequence
  //
  // Uses pslverr_inject_once=1 instead of pslverr_inject=1 so that only
  // the first APB transfer sees PSLVERR.  The flag auto-clears after one
  // transfer, allowing the sequence's recovery phase to complete cleanly.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_007_seq seq;

    phase.raise_objection(this, "error_007_test: starting");

    `uvm_info("ERROR_007", "=== ERROR_007 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Configure APB slave driver for one-shot PSLVERR injection
    // This auto-clears after one transfer so recovery write succeeds
    env.apb_agt.drv.pslverr_inject_once = 1;
    `uvm_info("ERROR_007", "APB driver pslverr_inject_once set to 1 (auto-clears after first transfer)", UVM_LOW)

    seq = ahb_mst_error_007_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_007", "=== ERROR_007 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_007_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_007", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_007", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
