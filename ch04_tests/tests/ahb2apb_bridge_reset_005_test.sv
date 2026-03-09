// =============================================================================
// File        : ahb2apb_bridge_reset_005_test.sv
// Description : TEST_RESET_005 — Reset recovery timing
//
// Purpose:
//   Verify the bridge can recover from hard reset within the expected
//   timing. Reset is asserted, then after a short recovery window the
//   ahb_mst_reset_005_seq sequence (which includes a #20 internal delay
//   for 2-cycle recovery) is driven to confirm the bridge accepts new
//   transactions.
//
// Pass criteria:
//   - Bridge accepts transactions after reset recovery
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (reset recovery path)
// =============================================================================

class ahb2apb_bridge_reset_005_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reset_005_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns           = 2;
    cfg.scoreboard_enable  = 0;
    cfg.ahb_mst_is_active  = UVM_ACTIVE;
    cfg.apb_slv_is_active  = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
    `uvm_info("RESET_005", "Scoreboard DISABLED (reset recovery path)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reset_005_seq seq;
    virtual reset_ctrl_if rst_vif;

    phase.raise_objection(this, "reset_005_test: starting");

    `uvm_info("RESET_005", "=== TEST_RESET_005 START ===", UVM_NONE)

    if (!uvm_config_db#(virtual reset_ctrl_if)::get(null, "", "rst_vif", rst_vif))
      `uvm_fatal("NOVIF", "no rst_vif in config_db")

    // Assert reset to start fresh
    rst_vif.assert_reset(5);

    // 3 cycles after reset deassert — the seq has #20 for recovery
    #30;

    seq = ahb_mst_reset_005_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("RESET_005", "=== TEST_RESET_005 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reset_005_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("RESET_005", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("RESET_005", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
