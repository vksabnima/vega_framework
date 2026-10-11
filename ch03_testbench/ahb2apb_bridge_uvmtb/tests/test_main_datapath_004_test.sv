// =============================================================================
// FILE: tests/test_main_datapath_004_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_004 (in_order_sequence_data_integrity)
// DESCRIPTION: Verifies multi-transfer sequence data integrity: a four-beat
//              INCR4 word-write burst writes distinct patterns (all 1s, all 0s,
//              alternating) across HADDR=0x0000_4000..0x0000_400C, then the same
//              four addresses are read back in order and compared. Confirms the
//              bridge re-drives each beat onto PADDR/PWDATA in order, returns the
//              stored data unchanged on HRDATA, and preserves address ordering
//              (VG1/VG2/VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR /
//              HWDATA->PWDATA propagation, read-back data integrity, and
//              one-to-one beat ordering are checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_004 — main_datapath category, sequence_handling.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_004 extends uvm_test;

  `uvm_component_utils(test_main_datapath_004)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_004", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR / HWDATA->PWDATA, read-back data
    // integrity, and the in-order beat mapping are checked (VG1/VG2/VG3/VG4/VG6).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 8;  // four-beat write burst + four-beat read-back

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_004: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_004: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive INCR4 word-write burst then in-order read-back ───────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_004_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_004: starting");

    `uvm_info("DP004", "========== TEST_MAIN_DATAPATH_004 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the distinct-pattern INCR4 word-write burst then read-back on AHB
    ahb_seq = ahb_mst_test_main_datapath_004_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the final read beat to propagate through the bridge.
    #200ns;

    `uvm_info("DP004", "========== TEST_MAIN_DATAPATH_004 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_004: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP004", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP004",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_004
