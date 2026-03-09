// =============================================================================
// File        : ahb2apb_bridge_error_009_test.sv
// Description : Error Test 009 — Address Error Scenarios
//
// Purpose:
//   Verify additional address error scenarios and confirm correct error
//   response generation by the bridge.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Enabled (enable=1) with skip_register_range=1, skip_error_txns=1
//   so error transactions are excluded from comparison.
// =============================================================================

class ahb2apb_bridge_error_009_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_009_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config with scoreboard enabled
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
  // end_of_elaboration_phase: enable scoreboard with error skipping
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
    env.scb.skip_register_range = 1;
    env.scb.skip_error_txns = 1;
    `uvm_info("ERROR_009", "Scoreboard ENABLED (skip_register_range=1, skip_error_txns=1)", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: drive error 009 sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_009_seq seq;

    phase.raise_objection(this, "error_009_test: starting");

    `uvm_info("ERROR_009", "=== ERROR_009 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    seq = ahb_mst_error_009_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_009", "=== ERROR_009 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_009_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_009", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_009", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
