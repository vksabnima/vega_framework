// =============================================================================
// File        : ahb2apb_bridge_datapath_004_test.sv
// Description : Datapath Test 004 — Read Data Forwarding
//
// Purpose:
//   Verify that read data returned from the APB slave reaches the AHB master
//   unchanged. Exercises multiple read transactions to confirm correct read
//   data forwarding through the bridge. [VG3]
//
// Pass criteria:
//   - Scoreboard passes: all APB read data matches corresponding AHB read data
//   - No UVM_FATAL or UVM_ERROR
//
// Confidence: HIGH — core datapath verification.
// =============================================================================

class ahb2apb_bridge_datapath_004_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_datapath_004_test)

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
    cfg.num_txns = 6;
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
  endfunction

  // =========================================================================
  // run_phase: drive read data forwarding sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_datapath_004_seq seq;

    phase.raise_objection(this, "DATAPATH_004: starting");

    `uvm_info("DATAPATH_004", "=== TEST START ===", UVM_NONE)

    // Wait for reset deassertion
    #150;

    // Create and start sequence
    seq = ahb_mst_datapath_004_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("DATAPATH_004", "=== TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "DATAPATH_004: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED based on UVM error count
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("DATAPATH_004", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("DATAPATH_004", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
