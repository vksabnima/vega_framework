// =============================================================================
// FILE: tests/test_cross_feature_003_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CROSS_FEATURE_003 (ctrl_register_write_during_active_transfer)
// DESCRIPTION: Exposes mid-transfer reconfiguration hazards when CTRL.ENABLE is
//              cleared while a data transfer is still active. Drives a write that
//              the APB peripheral stalls one cycle, issues a concurrent CTRL
//              register write attempting to clear ENABLE, then lets the original
//              write complete and reads back CTRL / STATUS. Verifies the in-flight
//              beat is delivered uncorrupted (PWDATA=0xCAFEF00D, HRESP=0), the
//              CTRL write applies cleanly (ENABLE=0), and no spurious sticky error
//              is latched.
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              cross-feature sequence. Scoreboard enabled so address propagation
//              and data-integrity checks run automatically (VG1, VG2, VG6).
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_003 — cross_feature category, parent feature
//     ctrl_register_access.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_cross_feature_003 extends uvm_test;

  `uvm_component_utils(test_cross_feature_003)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_cross_feature_003", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so data integrity / sticky status are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_003: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_cross_feature_003: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the ctrl-write-during-active-transfer flow ────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_cross_feature_003_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_cross_feature_003: starting");

    `uvm_info("XFEAT003", "========== TEST_CROSS_FEATURE_003 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the stalled write / concurrent CTRL write / register read-back stimulus
    ahb_seq = ahb_mst_test_cross_feature_003_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("XFEAT003", "========== TEST_CROSS_FEATURE_003 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_cross_feature_003: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("XFEAT003", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("XFEAT003",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_cross_feature_003
