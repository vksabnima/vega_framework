// =============================================================================
// File        : ahb2apb_bridge_reg_access_005_test.sv
// Description : TEST_REGISTER_ACCESS_005 — Error address capture
//
// Purpose:
//   Verify that the bridge captures the address of a transaction that
//   results in an error into the error address register. Drives
//   transactions that trigger errors and reads the error address register
//   to confirm correct capture.
//
// Pass criteria:
//   - Simulation completes without UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (mix of register reads and error transactions,
//             too complex for automated scoreboard matching)
// =============================================================================

class ahb2apb_bridge_reg_access_005_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reg_access_005_test)

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
    `uvm_info("REG_005", "Scoreboard DISABLED (error + register mix)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reg_access_005_seq ahb_seq;

    phase.raise_objection(this, "reg_access_005_test: starting");

    `uvm_info("REG_005", "=== TEST_REGISTER_ACCESS_005 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    ahb_seq = ahb_mst_reg_access_005_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("REG_005", "=== TEST_REGISTER_ACCESS_005 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reg_access_005_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("REG_005", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("REG_005", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
