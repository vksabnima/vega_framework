// =============================================================================
// File        : ahb2apb_bridge_reset_002_test.sv
// Description : TEST_RESET_002 — Soft reset abort transfer
//
// Purpose:
//   Verify that the bridge can handle a soft-reset scenario that aborts
//   an in-flight transfer. The ahb_mst_reset_002_seq sequence drives a
//   small number of transactions to exercise the abort path.
//
// Pass criteria:
//   - Simulation completes without UVM_FATAL or UVM_ERROR
//   - Scoreboard confirms transaction integrity
//
// Scoreboard: ENABLED
// =============================================================================

class ahb2apb_bridge_reset_002_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reset_002_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns           = 4;
    cfg.scoreboard_enable  = 1;
    cfg.ahb_mst_is_active  = UVM_ACTIVE;
    cfg.apb_slv_is_active  = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
    `uvm_info("RESET_002", "Scoreboard ENABLED", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reset_002_seq ahb_seq;

    phase.raise_objection(this, "reset_002_test: starting");

    `uvm_info("RESET_002", "=== TEST_RESET_002 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    ahb_seq = ahb_mst_reset_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("RESET_002", "=== TEST_RESET_002 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reset_002_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("RESET_002", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("RESET_002", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
