// =============================================================================
// File        : ahb2apb_bridge_error_005_test.sv
// Description : Error Test 005 — Timeout Value Configuration
//
// Purpose:
//   Verify that the timeout counter threshold is configurable via the
//   timeout value register.  Sets pready_delay=20 on the APB slave driver
//   and exercises the sequence that programs different timeout threshold
//   values to confirm correct timeout behavior at various settings.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Disabled (enable=0) because this test mixes timeout error transactions
//   with register reads that the scoreboard cannot reliably compare.
// =============================================================================

class ahb2apb_bridge_error_005_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_005_test)

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
  // end_of_elaboration_phase: disable scoreboard for timeout test
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    `uvm_info("ERROR_005", "Scoreboard DISABLED — timeout + register reads", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: configure APB driver for timeout and drive sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_005_seq seq;

    phase.raise_objection(this, "error_005_test: starting");

    `uvm_info("ERROR_005", "=== ERROR_005 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Configure APB slave driver to delay PREADY, forcing timeout
    env.apb_agt.drv.pready_delay = 20;
    `uvm_info("ERROR_005", "APB driver pready_delay set to 20", UVM_LOW)

    seq = ahb_mst_error_005_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_005", "=== ERROR_005 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_005_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_005", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_005", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
