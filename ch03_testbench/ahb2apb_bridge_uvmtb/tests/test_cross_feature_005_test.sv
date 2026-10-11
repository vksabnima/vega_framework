// =============================================================================
// FILE: tests/test_cross_feature_005_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CROSS_FEATURE_005 (hsel_deassert_mid_transfer)
// DESCRIPTION: Exposes protocol/state-machine faults when HSEL is deasserted
//              (HSEL=0) after a transfer has been captured but before target
//              completion. Drives a read to 0x0000_6000 that the peripheral
//              stalls (PREADY=0 two cycles) then completes with
//              PRDATA=0xBEEF_CACE; HSEL is dropped mid-transfer (HTRANS=IDLE)
//              while the captured beat is still active in the target. Verifies
//              the already-captured beat is not aborted (HRDATA=0xBEEF_CACE,
//              HRESP=0), that no spurious second APB transfer is launched from
//              the deselected cycle, and that the FSM returns to a clean IDLE
//              (STATUS=0x00000001).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              cross-feature sequence. Scoreboard enabled so data-integrity and
//              transaction-count checks run automatically (VG1, VG3, VG4, VG6).
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_005 — cross_feature category, parent feature
//     source_side_interface_signals.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_cross_feature_005 extends uvm_test;

  `uvm_component_utils(test_cross_feature_005)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_cross_feature_005", uvm_component parent);
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
      `uvm_fatal("NOVIF", "test_cross_feature_005: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_005: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the stalled-read / HSEL-deassert flow ─────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_cross_feature_005_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_cross_feature_005: starting");

    `uvm_info("XFEAT005", "========== TEST_CROSS_FEATURE_005 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the stalled read / HSEL-deassert / completion / STATUS read stimulus
    ahb_seq = ahb_mst_test_cross_feature_005_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("XFEAT005", "========== TEST_CROSS_FEATURE_005 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_cross_feature_005: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("XFEAT005", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("XFEAT005",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_cross_feature_005
