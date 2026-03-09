// =============================================================================
// File        : ahb2apb_bridge_error_002_test.sv
// Description : Error Test 002 — Address Error No APB
//
// Purpose:
//   Verify that when an address error is detected, no APB transaction is
//   generated.  The bridge should respond with an error on AHB without
//   forwarding the transaction to the APB bus.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Enabled (enable=1) with skip_error_txns=1 so error transactions are
//   excluded from comparison.
// =============================================================================

class ahb2apb_bridge_error_002_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_002_test)

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
    cfg.num_txns = 4;
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
    env.scb.skip_error_txns = 1;
    `uvm_info("ERROR_002", "Scoreboard ENABLED — skip_error_txns=1", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: drive address error no-APB sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_002_seq seq;

    phase.raise_objection(this, "error_002_test: starting");

    `uvm_info("ERROR_002", "=== ERROR_002 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    seq = ahb_mst_error_002_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_002", "=== ERROR_002 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_002_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_002", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_002", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
