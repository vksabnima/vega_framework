// =============================================================================
// FILE: tests/ahb2apb_bridge_bringup_test.sv
// =============================================================================
// COMPONENT  : Bringup Test
// DESCRIPTION: Drives ONE transaction only. No scoreboard checks.
//              Pass if simulation completes without UVM_FATAL or UVM_ERROR.
//              Purpose: If this fails, the TB infrastructure is broken (not DUT).
//
// DERIVED FROM:
//   - Section 3 job description: "Drive ONE transaction only, no scoreboard
//     checks, pass if simulation completes without UVM_FATAL or UVM_ERROR."
//   - Manifest: clock, reset, drain_time.
//
// CONFIDENCE: HIGH — minimal test, standard UVM pattern.
// =============================================================================

class ahb2apb_bridge_bringup_test extends uvm_test;

  `uvm_component_utils(ahb2apb_bridge_bringup_test)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "ahb2apb_bridge_bringup_test", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Disable scoreboard for bringup — just proving infrastructure works
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 1;

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "bringup_test: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "bringup_test: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: Drive one transaction ─────────────────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_bringup_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    // Raise objection — only in test [U6]
    phase.raise_objection(this, "bringup_test: starting");

    `uvm_info("BRINGUP", "========== BRINGUP TEST START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background
    // It runs forever [U3], so we fork it off
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive ONE transaction on AHB
    ahb_seq = ahb_mst_bringup_seq::type_id::create("ahb_seq");
    ahb_seq.num_txns = 1;
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow DUT to complete processing
    // Manifest: drain_time_ns = 200
    #200ns;

    `uvm_info("BRINGUP", "========== BRINGUP TEST COMPLETE ==========", UVM_NONE)

    // Drop objection [U6]
    phase.drop_objection(this, "bringup_test: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    // Manifest pass_criteria: max_uvm_errors=0, max_uvm_fatals=0
    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("BRINGUP", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("BRINGUP", "\n\n***** TEST FAILED *****\n", UVM_NONE)
    end
  endfunction : report_phase

endclass : ahb2apb_bridge_bringup_test