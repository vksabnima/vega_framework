// =============================================================================
// File        : ahb2apb_bridge_connectivity_002_test.sv
// Description : Connectivity Test 002 — AHB Wait State Stability
//
// Purpose:
//   Verify that the bridge correctly handles APB wait states by inserting
//   HREADY_OUT=0 on the AHB side when the APB slave deasserts PREADY.
//   The APB slave driver is configured with pready_delay=3 to inject wait
//   states into every APB transfer.
//
// Pass criteria:
//   - Scoreboard passes: AHB transactions match APB transactions
//   - No UVM_FATAL or UVM_ERROR
//
// Confidence: HIGH — straightforward wait-state injection test.
// =============================================================================

class ahb2apb_bridge_connectivity_002_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_connectivity_002_test)

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
    cfg.num_txns = 2;
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
  // run_phase: configure APB wait states, then drive transactions
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_connectivity_002_seq seq;

    phase.raise_objection(this, "CONN_002: starting");

    `uvm_info("CONN_002", "=== TEST START ===", UVM_NONE)

    // Wait for reset deassertion
    #150;

    // Configure APB slave to insert 3-cycle wait states
    env.apb_agt.drv.pready_delay = 3;

    // Create and start sequence
    seq = ahb_mst_connectivity_002_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("CONN_002", "=== TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "CONN_002: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED based on UVM error count
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("CONN_002", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("CONN_002", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
