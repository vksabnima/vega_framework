// =============================================================================
// File        : ahb2apb_bridge_reset_004_test.sv
// Description : TEST_RESET_004 — Reset safe state timing
//
// Purpose:
//   Verify that the bridge reaches a safe (idle) state after hard reset
//   within the expected timing window. Pre-reset traffic is driven, reset
//   is asserted, and after re-initialization the post-reset sequence
//   confirms the bridge responds correctly.
//
// Pass criteria:
//   - Bridge reaches safe state after reset deassertion
//   - Post-reset transactions complete without errors
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (reset disrupts transaction matching)
// =============================================================================

class ahb2apb_bridge_reset_004_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reset_004_test)

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
    `uvm_info("RESET_004", "Scoreboard DISABLED (reset disrupts matching)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reset_004_seq   pre_seq;
    ahb_mst_reset_004_post_seq  post_seq;
    virtual reset_ctrl_if       rst_vif;

    phase.raise_objection(this, "reset_004_test: starting");

    `uvm_info("RESET_004", "=== TEST_RESET_004 START ===", UVM_NONE)

    if (!uvm_config_db#(virtual reset_ctrl_if)::get(null, "", "rst_vif", rst_vif))
      `uvm_fatal("NOVIF", "no rst_vif in config_db")

    // Wait for initial reset deassertion + bridge initialisation
    #150;

    // Pre-reset phase — drive transactions
    pre_seq = ahb_mst_reset_004_seq::type_id::create("pre_seq");
    pre_seq.start(env.ahb_agt.sqr);

    // Assert hard reset
    rst_vif.assert_reset(5);

    // Wait for re-initialization
    #150;

    // Post-reset phase — verify bridge reaches safe state
    post_seq = ahb_mst_reset_004_post_seq::type_id::create("post_seq");
    post_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("RESET_004", "=== TEST_RESET_004 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reset_004_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("RESET_004", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("RESET_004", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
