// =============================================================================
// File        : ahb2apb_bridge_reg_access_003_test.sv
// Description : TEST_REGISTER_ACCESS_003 — Status register access
//
// Purpose:
//   Verify read access to the bridge status register. Reads the status
//   register and checks that it returns expected default/current values.
//   This test only performs register reads — no APB data transactions
//   are expected.
//
// Pass criteria:
//   - Simulation completes without UVM_FATAL or UVM_ERROR
//
// Scoreboard: DISABLED (only register reads, no APB transactions)
// =============================================================================

class ahb2apb_bridge_reg_access_003_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reg_access_003_test)

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
    `uvm_info("REG_003", "Scoreboard DISABLED (register reads only)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reg_access_003_seq ahb_seq;

    phase.raise_objection(this, "reg_access_003_test: starting");

    `uvm_info("REG_003", "=== TEST_REGISTER_ACCESS_003 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    ahb_seq = ahb_mst_reg_access_003_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("REG_003", "=== TEST_REGISTER_ACCESS_003 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reg_access_003_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("REG_003", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("REG_003", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
