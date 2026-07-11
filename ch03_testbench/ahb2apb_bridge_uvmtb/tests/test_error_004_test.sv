// =============================================================================
// FILE: tests/test_error_004_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_004
//              (addr_error_during_active_transfer_with_reset_recovery)
// DESCRIPTION: Verifies address-error detection on a request following a valid
//              in-flight transfer, then verifies a hard/soft reset cleanly
//              aborts and clears the sticky ADDR_ERR and captured debug
//              registers: a good write at 0x0000_5000 (0x1111_2222) completes
//              cleanly (HRESP=0), then an invalid-range WRITE at 0xFEED_0000
//              following live activity sets ADDR_ERR, returns an HRESP error,
//              asserts the sticky ERR_INT, and captures ERROR_ADDR=0xFEED_0000
//              with ERROR_INFO recording direction=write. The model then
//              recovers via W1C + hard reset (registers returned to Table 8
//              values, error log cleared) and a post-recovery write+read at
//              0x0000_6000 returns 0x9999_8888 with a clean error log.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the error sequence. Scoreboard enabled so address
//              propagation and error-response checks run automatically
//              (VG1, VG2, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_004 — error category, address_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_004 extends uvm_test;

  `uvm_component_utils(test_error_004)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_004", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so address propagation / error response are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_004: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_004: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the addr-error-during-active-transfer / reset flow ─────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_004_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_004: starting");

    `uvm_info("ERR004", "========== TEST_ERROR_004 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the addr-error-during-active-transfer detection / reset-recovery flow
    ahb_seq = ahb_mst_test_error_004_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR004", "========== TEST_ERROR_004 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_004: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR004", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR004",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_004
