// =============================================================================
// File        : ahb2apb_bridge_stress_001_test.sv
// Description : TEST_STRESS_001 — Back-to-back stress test
//
// Purpose:
//   Stress the bridge with a large number (200) of back-to-back
//   transactions to verify sustained throughput and data integrity
//   under heavy load. Extended drain time is used to allow all
//   transactions to complete.
//
// Pass criteria:
//   - All 200 transactions complete without loss or corruption
//   - Scoreboard confirms address, data, and direction integrity
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: ENABLED
// =============================================================================

class ahb2apb_bridge_stress_001_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_stress_001_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns           = 200;
    cfg.scoreboard_enable  = 1;
    cfg.ahb_mst_is_active  = UVM_ACTIVE;
    cfg.apb_slv_is_active  = UVM_ACTIVE;
    cfg.drain_time_ns      = 500;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
    env.scb.skip_error_txns = 1;
    `uvm_info("STRESS_001", "Scoreboard ENABLED (skip_error_txns=1)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_stress_001_seq ahb_seq;

    phase.raise_objection(this, "stress_001_test: starting");

    `uvm_info("STRESS_001", "=== TEST_STRESS_001 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    ahb_seq = ahb_mst_stress_001_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Extended drain time for many transactions
    #(cfg.drain_time_ns);

    `uvm_info("STRESS_001", "=== TEST_STRESS_001 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "stress_001_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("STRESS_001", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("STRESS_001", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
