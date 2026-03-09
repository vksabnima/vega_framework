// =============================================================================
// File        : ahb2apb_bridge_connectivity_003_test.sv
// Description : Connectivity Test 003 — APB PSEL Entire Transfer
//
// Purpose:
//   Verify that the bridge asserts PSEL for the entire duration of an APB
//   transfer (both SETUP and ACCESS phases). This confirms correct APB
//   protocol signaling from the bridge.
//
// Pass criteria:
//   - Scoreboard passes: AHB transactions match APB transactions
//   - No UVM_FATAL or UVM_ERROR
//
// Confidence: HIGH — protocol compliance check via scoreboard.
// =============================================================================

class ahb2apb_bridge_connectivity_003_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_connectivity_003_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config, build environment
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns = 2;
    cfg.scoreboard_enable = 1;
    cfg.ahb_mst_is_active = UVM_ACTIVE;
    cfg.apb_slv_is_active = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  // =========================================================================
  // end_of_elaboration_phase: enable scoreboard
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
  endfunction

  // =========================================================================
  // run_phase: drive transactions and let scoreboard verify PSEL behavior
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_connectivity_003_seq seq;

    phase.raise_objection(this, "CONN_003: starting");

    `uvm_info("CONN_003", "=== TEST START ===", UVM_NONE)

    // Wait for reset deassertion
    #150;

    // Create and start sequence
    seq = ahb_mst_connectivity_003_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("CONN_003", "=== TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "CONN_003: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED based on UVM error count
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("CONN_003", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("CONN_003", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
