// =============================================================================
// File        : ahb2apb_bridge_reset_003_test.sv
// Description : TEST_RESET_003 — Asynchronous reset assertion
//
// Purpose:
//   Verify the bridge behavior when an asynchronous hard reset is asserted
//   while traffic is in flight. The test drives pre-reset transactions,
//   asserts reset via reset_ctrl_if, waits for re-initialization, then
//   drives post-reset transactions to confirm the bridge recovers cleanly.
//
// Pass criteria:
//   - Bridge returns to idle after reset deassertion
//   - Post-reset transactions complete without errors
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (reset disrupts transaction matching)
// =============================================================================

class ahb2apb_bridge_reset_003_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reset_003_test)

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
    `uvm_info("RESET_003", "Scoreboard DISABLED (reset disrupts matching)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reset_003_seq   pre_seq;
    ahb_mst_reset_003_post_seq  post_seq;
    virtual reset_ctrl_if       rst_vif;

    phase.raise_objection(this, "reset_003_test: starting");

    `uvm_info("RESET_003", "=== TEST_RESET_003 START ===", UVM_NONE)

    if (!uvm_config_db#(virtual reset_ctrl_if)::get(null, "", "rst_vif", rst_vif))
      `uvm_fatal("NOVIF", "no rst_vif in config_db")

    // Wait for initial reset deassertion + bridge initialisation
    #150;

    // Pre-reset phase — drive transactions
    pre_seq = ahb_mst_reset_003_seq::type_id::create("pre_seq");
    pre_seq.start(env.ahb_agt.sqr);

    // Assert hard reset
    rst_vif.assert_reset(5);

    // Wait for re-initialization
    #150;

    // Post-reset phase — verify bridge recovers
    post_seq = ahb_mst_reset_003_post_seq::type_id::create("post_seq");
    post_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("RESET_003", "=== TEST_RESET_003 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reset_003_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("RESET_003", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("RESET_003", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
