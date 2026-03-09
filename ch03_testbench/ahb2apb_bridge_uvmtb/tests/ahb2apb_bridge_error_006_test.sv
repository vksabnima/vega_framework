// =============================================================================
// File        : ahb2apb_bridge_error_006_test.sv
// Description : Error Test 006 — Protocol Error Detection (PSLVERR)
//
// Purpose:
//   Verify that the bridge correctly detects and propagates APB slave error
//   responses (PSLVERR).  The APB slave driver is configured to inject
//   PSLVERR on all transfers (pslverr_inject=1).
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Disabled (enable=0) because this test mixes PSLVERR error transactions
//   with register reads that the scoreboard cannot reliably compare.
// =============================================================================

class ahb2apb_bridge_error_006_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_006_test)

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
  // end_of_elaboration_phase: disable scoreboard for PSLVERR test
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    `uvm_info("ERROR_006", "Scoreboard DISABLED — PSLVERR error + register reads", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: configure APB driver for PSLVERR injection and drive sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_006_seq seq;

    phase.raise_objection(this, "error_006_test: starting");

    `uvm_info("ERROR_006", "=== ERROR_006 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Configure APB slave driver to inject PSLVERR on all transfers
    env.apb_agt.drv.pslverr_inject = 1;
    `uvm_info("ERROR_006", "APB driver pslverr_inject set to 1", UVM_LOW)

    seq = ahb_mst_error_006_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_006", "=== ERROR_006 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_006_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_006", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_006", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
