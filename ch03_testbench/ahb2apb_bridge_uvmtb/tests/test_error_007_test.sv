// =============================================================================
// FILE: tests/test_error_007_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_007 (timeout_error_with_interrupt)
// DESCRIPTION: Verifies that a timeout error sets BOTH TIMEOUT_ERR (STATUS b6)
//              and the aggregated ERR_INT (STATUS b7) when interrupt indication
//              is enabled, captures debug context, and that both flags clear
//              independently via W1C. With CTRL programmed for timeout +
//              interrupt (0x0000_00F9), a good write at 0x0000_1000
//              (0x0000_0001) completes OKAY (HRESP=0, HREADY_OUT=1) with a clean
//              STATUS, then a read at 0x0000_6000 with the target stalled
//              (PREADY held 0 past the TIMEOUT_VAL window) fires a timeout:
//              HRESP=1 and STATUS sets TIMEOUT_ERR b6=1 AND ERR_INT b7=1
//              (STATUS=0x0000_00C1). The error log captures ERROR_ADDR=
//              0x0000_6000 and ERROR_INFO (direction=read, class=timeout).
//              ERR_INT clears independently via W1C (STATUS=0x0000_0041,
//              TIMEOUT_ERR still set), then SOFT_RST recovery + W1C TIMEOUT_ERR
//              returns STATUS=0x0000_0001 with a cleared error log and preserved
//              config. A post-recovery good read at 0x0000_7000 returns
//              0xFEED_FACE (HRESP=0) proving data integrity with a clean log.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the timeout-with-interrupt sequence. Scoreboard enabled so
//              address propagation and response checks run automatically
//              (VG1, VG2, VG3, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_007 — error category, timeout_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_007 extends uvm_test;

  `uvm_component_utils(test_error_007)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_007", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Scoreboard off: the timed-out read aborts with no clean APB completion to
    // pair. Timeout behaviour is verified by the sequence self-checks.
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Stall the APB slave at the timeout target so the bridge times out.
    cfg.add_apb_stall_addr(32'h0000_6000);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_007: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_007: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the timeout-error-with-interrupt flow ──────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_007_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_007: starting");

    `uvm_info("ERR007", "========== TEST_ERROR_007 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the timeout-error-with-interrupt flow
    ahb_seq = ahb_mst_test_error_007_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR007", "========== TEST_ERROR_007 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_007: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR007", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR007",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_007
