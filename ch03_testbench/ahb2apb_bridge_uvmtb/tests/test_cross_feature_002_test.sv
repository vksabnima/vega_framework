// =============================================================================
// FILE: tests/test_cross_feature_002_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CROSS_FEATURE_002 (target_error_during_back_pressure)
// DESCRIPTION: Exposes error-latching faults when PSLVERR is asserted on the
//              same cycle the peripheral releases back-pressure (PREADY rises
//              with PSLVERR=1). Drives a read that the APB peripheral stalls for
//              several cycles, then completes with a coincident error, and
//              verifies the error propagates to the source (HRESP=1) and is
//              captured in the sticky STATUS / ERROR_ADDR / ERROR_INFO context.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the cross-feature sequence. Scoreboard enabled so address
//              propagation and error-response checks run automatically
//              (VG1, VG5, VG6).
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_002 — cross_feature category, parent feature
//     target_error_scenario.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_cross_feature_002 extends uvm_test;

  `uvm_component_utils(test_cross_feature_002)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_cross_feature_002", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so error propagation / sticky status are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_002: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_002: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the target-error-during-back-pressure flow ───────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_cross_feature_002_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_cross_feature_002: starting");

    `uvm_info("XFEAT002", "========== TEST_CROSS_FEATURE_002 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the stalled read / coincident error / register read-back stimulus
    ahb_seq = ahb_mst_test_cross_feature_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("XFEAT002", "========== TEST_CROSS_FEATURE_002 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_cross_feature_002: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("XFEAT002", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("XFEAT002",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_cross_feature_002
