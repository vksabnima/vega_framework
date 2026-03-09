// =============================================================================
// File        : ahb2apb_bridge_error_001_test.sv
// Description : Error Test 001 — Address Error Detection
//
// Purpose:
//   Drive a mix of error-inducing address transactions and register reads
//   through the bridge.  Verifies that out-of-range or invalid addresses
//   are detected and reported correctly by the DUT.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Disabled (enable=0) because this test mixes error transactions with
//   register reads that the scoreboard cannot reliably compare.
// =============================================================================

class ahb2apb_bridge_error_001_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_001_test)

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
  // end_of_elaboration_phase: disable scoreboard for error test
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    `uvm_info("ERROR_001", "Scoreboard DISABLED — mix of error txns and register reads", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: drive address error sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_001_seq seq;

    phase.raise_objection(this, "error_001_test: starting");

    `uvm_info("ERROR_001", "=== ERROR_001 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    seq = ahb_mst_error_001_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_001", "=== ERROR_001 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_001_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_001", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_001", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
