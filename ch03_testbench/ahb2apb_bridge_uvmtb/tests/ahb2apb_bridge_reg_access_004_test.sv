// =============================================================================
// File        : ahb2apb_bridge_reg_access_004_test.sv
// Description : TEST_REGISTER_ACCESS_004 — Status ready bit
//
// Purpose:
//   Verify the ready bit in the status register reflects the correct
//   bridge state. Performs transactions and reads the status register
//   to confirm the ready bit transitions appropriately.
//
// Pass criteria:
//   - Simulation completes without UVM_FATAL or UVM_ERROR
//   - Scoreboard confirms data integrity for non-register transactions
//
// Scoreboard: ENABLED (skip_register_range=1)
// =============================================================================

class ahb2apb_bridge_reg_access_004_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_reg_access_004_test)

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
    env.scb.skip_register_range = 1;
    `uvm_info("REG_004", "Scoreboard ENABLED (skip_register_range=1)", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_reg_access_004_seq ahb_seq;

    phase.raise_objection(this, "reg_access_004_test: starting");

    `uvm_info("REG_004", "=== TEST_REGISTER_ACCESS_004 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    ahb_seq = ahb_mst_reg_access_004_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("REG_004", "=== TEST_REGISTER_ACCESS_004 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "reg_access_004_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("REG_004", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("REG_004", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
