// =============================================================================
// File        : ahb2apb_bridge_cross_feature_001_test.sv
// Description : TEST_CROSS_FEATURE_001 — Reset during burst transfer
//
// Purpose:
//   Verify bridge behavior when a hard reset is asserted in the middle
//   of a burst transfer. The pre-reset sequence initiates burst traffic,
//   reset is asserted mid-burst, and the post-reset sequence confirms
//   the bridge recovers and can handle new transactions.
//
// Pass criteria:
//   - Bridge recovers cleanly after mid-burst reset
//   - Post-reset transactions complete without errors
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (reset disrupts transaction matching)
// =============================================================================

class ahb2apb_bridge_cross_feature_001_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_cross_feature_001_test)

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
    `uvm_info("CROSS_001", "Scoreboard DISABLED (reset disrupts matching)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_cross_feature_001_pre_seq   pre_seq;
    ahb_mst_cross_feature_001_post_seq  post_seq;
    virtual reset_ctrl_if               rst_vif;

    phase.raise_objection(this, "cross_feature_001_test: starting");

    `uvm_info("CROSS_001", "=== TEST_CROSS_FEATURE_001 START ===", UVM_NONE)

    if (!uvm_config_db#(virtual reset_ctrl_if)::get(null, "", "rst_vif", rst_vif))
      `uvm_fatal("NOVIF", "no rst_vif in config_db")

    // Wait for initial reset deassertion + bridge initialisation
    #150;

    // Pre-reset phase — drive burst transactions
    pre_seq = ahb_mst_cross_feature_001_pre_seq::type_id::create("pre_seq");
    pre_seq.start(env.ahb_agt.sqr);

    // Assert hard reset mid-burst
    rst_vif.assert_reset(3);

    // Wait for re-initialization
    #150;

    // Post-reset phase — verify bridge recovers
    post_seq = ahb_mst_cross_feature_001_post_seq::type_id::create("post_seq");
    post_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("CROSS_001", "=== TEST_CROSS_FEATURE_001 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "cross_feature_001_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("CROSS_001", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("CROSS_001", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
