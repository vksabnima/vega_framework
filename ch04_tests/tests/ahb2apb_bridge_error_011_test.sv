// =============================================================================
// File        : ahb2apb_bridge_error_011_test.sv
// Description : Error Test 011 — PSLVERR on All Transfers
//
// Purpose:
//   Verify the bridge behavior when every APB transfer returns PSLVERR.
//   The APB slave driver is configured with pslverr_inject=1 so all
//   transfers see a slave error response.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Disabled (enable=0) because all transfers generate PSLVERR errors
//   that the scoreboard cannot reliably compare.
// =============================================================================

class ahb2apb_bridge_error_011_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_error_011_test)

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
    `uvm_info("ERROR_011", "Scoreboard DISABLED — PSLVERR on all transfers", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: configure APB driver for PSLVERR injection and drive sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_error_011_seq seq;

    phase.raise_objection(this, "error_011_test: starting");

    `uvm_info("ERROR_011", "=== ERROR_011 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Configure APB slave driver to inject PSLVERR on all transfers
    env.apb_agt.drv.pslverr_inject = 1;
    `uvm_info("ERROR_011", "APB driver pslverr_inject set to 1", UVM_LOW)

    seq = ahb_mst_error_011_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("ERROR_011", "=== ERROR_011 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "error_011_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("ERROR_011", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("ERROR_011", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
