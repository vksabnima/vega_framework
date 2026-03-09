// =============================================================================
// File        : ahb2apb_bridge_datapath_010_test.sv
// Description : Datapath Test 010
//
// Purpose:
//   Verify datapath integrity for the scenario exercised by the
//   ahb_mst_datapath_010_seq sequence.
//
// Pass criteria:
//   - Scoreboard passes: all data comparisons match
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: ENABLED (skip_register_range=1)
// =============================================================================

class ahb2apb_bridge_datapath_010_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_datapath_010_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config, build environment
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns = 8;
    cfg.scoreboard_enable = 1;
    cfg.ahb_mst_is_active = UVM_ACTIVE;
    cfg.apb_slv_is_active = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  // =========================================================================
  // end_of_elaboration_phase: enable scoreboard
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 1;
    env.scb.skip_register_range = 1;
    `uvm_info("DATAPATH_010", "Scoreboard ENABLED (skip_register_range=1)", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: drive datapath 010 sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_datapath_010_seq seq;

    phase.raise_objection(this, "datapath_010_test: starting");

    `uvm_info("DATAPATH_010", "=== DATAPATH_010 TEST START ===", UVM_NONE)

    // Wait for reset deassertion
    #150;

    seq = ahb_mst_datapath_010_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("DATAPATH_010", "=== DATAPATH_010 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "datapath_010_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED based on UVM error count
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("DATAPATH_010", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("DATAPATH_010", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
