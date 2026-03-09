// =============================================================================
// File        : ahb2apb_bridge_protocol_004_test.sv
// Description : Protocol Test 004 — Wait State Handling
//
// Purpose:
//   Verify the bridge correctly handles APB wait states (PREADY delays).
//   The APB slave driver is configured with pready_delay=3 to insert wait
//   states, confirming the bridge holds the AHB bus appropriately.
//
// Pass criteria:
//   - Scoreboard passes: all data integrity maintained through wait states
//   - No UVM_FATAL or UVM_ERROR
//
// Scoreboard: ENABLED (skip_register_range=1)
// =============================================================================

class ahb2apb_bridge_protocol_004_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_protocol_004_test)

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
    `uvm_info("PROTOCOL_004", "Scoreboard ENABLED (skip_register_range=1)", UVM_LOW)
  endfunction

  // =========================================================================
  // run_phase: configure APB driver with wait states and drive sequence
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_protocol_004_seq seq;

    phase.raise_objection(this, "protocol_004_test: starting");

    `uvm_info("PROTOCOL_004", "=== PROTOCOL_004 TEST START ===", UVM_NONE)

    // Wait for reset deassertion + initialization
    #150;

    // Configure APB slave driver to insert wait states
    env.apb_agt.drv.pready_delay = 3;
    `uvm_info("PROTOCOL_004", "APB driver pready_delay set to 3", UVM_LOW)

    seq = ahb_mst_protocol_004_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("PROTOCOL_004", "=== PROTOCOL_004 TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "protocol_004_test: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("PROTOCOL_004", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("PROTOCOL_004", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
