// =============================================================================
// File        : ahb2apb_bridge_datapath_001_test.sv
// Description : TEST_MAIN_DATAPATH_001 — Single write conversion test
//
// XTP Reference:
//   test_id      : TEST_MAIN_DATAPATH_001
//   name         : single_write_conversion
//   req_ref      : REQ_003
//   pass_criteria: Single AHB beat → single APB transfer.
//                  Address and data forwarded correctly. Read-back confirms.
//
// Scoreboard: ENABLED — verifies VG1 (address), VG2 (write data),
//             VG3 (read data), VG4 (direction), VG6 (count match)
// =============================================================================

class ahb2apb_bridge_datapath_001_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_datapath_001_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns           = 2;           // 1 write + 1 read
    cfg.scoreboard_enable  = 1;
    cfg.ahb_mst_is_active  = UVM_ACTIVE;
    cfg.apb_slv_is_active  = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
    `uvm_info("DATAPATH_001", "Scoreboard ENABLED", UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    ahb_mst_datapath_001_seq ahb_seq;

    phase.raise_objection(this, "datapath_001_test: starting");

    `uvm_info("DATAPATH_001", "=== TEST_MAIN_DATAPATH_001 START ===", UVM_NONE)

    // Wait for reset deassertion + bridge initialisation
    #150;

    ahb_seq = ahb_mst_datapath_001_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time
    #(cfg.drain_time_ns);

    `uvm_info("DATAPATH_001", "=== TEST_MAIN_DATAPATH_001 COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "datapath_001_test: done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("DATAPATH_001", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("DATAPATH_001", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
