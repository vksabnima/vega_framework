// =============================================================================
// File        : ahb2apb_bridge_cross_feature_002_test.sv
// Description : TEST_CROSS_FEATURE_002 — Timeout error during register access
//
// Purpose:
//   Verify bridge behavior when the APB slave introduces excessive
//   PREADY delays (pready_delay=20) that cause timeout conditions
//   during register accesses. This tests the interaction between
//   the timeout mechanism and register read/write paths.
//
// Pass criteria:
//   - Bridge handles timeout conditions gracefully
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (timeout + register reads)
// =============================================================================

class ahb2apb_bridge_cross_feature_002_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_cross_feature_002_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns           = 10;
    cfg.scoreboard_enable  = 0;
    cfg.ahb_mst_is_active  = UVM_ACTIVE;
    cfg.apb_slv_is_active  = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    `uvm_info("CROSS_002", "Scoreboard DISABLED (timeout + register reads)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_cross_feature_002_seq ahb_seq;

    phase.raise_objection(this, "cross_feature_002_test: starting");

    `uvm_info("CROSS_002", "=== TEST_CROSS_FEATURE_002 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    // Configure APB slave driver with excessive PREADY delay for timeout
    env.apb_agt.drv.pready_delay = 20;

    ahb_seq = ahb_mst_cross_feature_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("CROSS_002", "=== TEST_CROSS_FEATURE_002 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "cross_feature_002_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("CROSS_002", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("CROSS_002", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
