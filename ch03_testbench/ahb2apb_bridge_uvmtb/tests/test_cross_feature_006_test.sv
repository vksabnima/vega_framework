// =============================================================================
// FILE: tests/test_cross_feature_006_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CROSS_FEATURE_006 (back_to_back_with_error_recovery)
// DESCRIPTION: Exposes error-isolation faults in a back-to-back stream where one
//              beat errors (PSLVERR=1 on beat 2) and the following beat must
//              complete cleanly. Drives three streamed word writes
//              (0x0400 / 0x0404 / 0x0408) where only beat 2 takes a target error,
//              then reads back STATUS / ERROR_ADDR / ERROR_INFO and finally a
//              data read-back of beat 3 (0x0408 -> PRDATA=0x3333_3333). Verifies
//              an error on beat 2 (HRESP=1) does not corrupt or abort beats 1 or
//              3 (both HRESP=0), that sticky error bits and ERROR_ADDR=0x00000404
//              latch from the faulting beat, and that beat 3 data integrity is
//              preserved (HRDATA=0x3333_3333, HRESP=0).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              cross-feature sequence. Scoreboard enabled so data-integrity and
//              transaction-count checks run automatically (VG1-VG6).
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_006 — cross_feature category, parent feature
//     error_response_timing.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_cross_feature_006 extends uvm_test;

  `uvm_component_utils(test_cross_feature_006)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_cross_feature_006", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so data integrity / transaction-count are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_006: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_006: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the back-to-back stream with mid-stream error ─────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_cross_feature_006_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_cross_feature_006: starting");

    `uvm_info("XFEAT006", "========== TEST_CROSS_FEATURE_006 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the streamed write / error / recovery / register read-back stimulus
    ahb_seq = ahb_mst_test_cross_feature_006_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("XFEAT006", "========== TEST_CROSS_FEATURE_006 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_cross_feature_006: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("XFEAT006", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("XFEAT006",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_cross_feature_006
