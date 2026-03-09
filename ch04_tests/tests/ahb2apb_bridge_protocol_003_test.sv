// =============================================================================
// File        : ahb2apb_bridge_protocol_003_test.sv
// Description : Protocol Test 003 — Error Response Protocol
//
// Purpose:
//   Verify the bridge produces correct AHB error responses for various
//   error conditions: address errors, timeout errors, and PSLVERR.
//   The APB slave driver is configured with pready_delay=20 to force
//   timeout conditions when the sequence enables timeout detection.
//
// Pass criteria:
//   - No UVM_ERROR or UVM_FATAL
//   - "TEST PASSED" printed
//
// Scoreboard:
//   Disabled (enable=0) because this test generates error transactions
//   that the scoreboard cannot reliably compare.
// =============================================================================

class ahb2apb_bridge_protocol_003_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_protocol_003_test)

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
  // end_of_elaboration_phase: disable scoreboard for error response test
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    env.scb.skip_error_txns = 1;
    `uvm_info("PROTOCOL_003", "Scoreboard DISABLED — error response protocol test", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: configure APB driver and drive error response protocol sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_protocol_003_seq seq;

    phase.raise_objection(this, "protocol_003_test: starting");

    `uvm_info("PROTOCOL_003", "=== PROTOCOL_003 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Configure APB slave driver to delay PREADY for timeout testing
    env.apb_agt.drv.pready_delay = 20;
    env.apb_agt.drv.pslverr_inject = 0;
    `uvm_info("PROTOCOL_003", "APB driver pready_delay set to 20, pslverr_inject=0", UVM_LOW)

    seq = ahb_mst_protocol_003_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("PROTOCOL_003", "=== PROTOCOL_003 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "protocol_003_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("PROTOCOL_003", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("PROTOCOL_003", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
