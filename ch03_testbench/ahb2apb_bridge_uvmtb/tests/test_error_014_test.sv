// =============================================================================
// FILE: tests/test_error_014_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_014 (error_response_two_cycle_window_hresp_timing)
// DESCRIPTION: Verifies the precise cycle timing of HRESP assertion relative to
//              PSLVERR sampling and the error response window before HREADY_OUT
//              completes. With CTRL programmed for ENABLE=1 (0x0000_0001), a good
//              write at 0x0000_3000 (PWDATA=0x0000_0F0F) completes OKAY (PSEL setup
//              at T2, PENABLE active at T3, HREADY_OUT=1, HRESP=0) with a clean
//              STATUS. An injected write at 0x0000_3100 (PWDATA=0x0000_DEAD) with
//              PSLVERR=1, PREADY=1 sampled at the T3 active phase (PSEL=1,
//              PENABLE=1) fires the error: HRESP=1 at T4 held through the error
//              response window (T5..T6) with HREADY_OUT gated low until window
//              close. With ERR_INT_EN=1 (CTRL=0x0000_0009) a re-injection sets the
//              aggregated sticky STATUS.ERR_INT b7=1: STATUS=0x0000_00A1 (PSLVERR
//              b5=1, ERR_INT b7=1, READY b0=1), ERROR_ADDR=0x0000_3100, ERROR_INFO
//              direction=write. W1C of bits 7 and 5 (STATUS=0x0000_00A0) clears
//              both (STATUS=0x0000_0001); SOFT_RST (CTRL=0x0000_000B) clears the
//              error log preserving config (STATUS=0x0000_0009, ERROR_ADDR=0,
//              ERROR_INFO=0). After reconfigure (CTRL=0x0000_0001), a post-recovery
//              good read at 0x0000_3104 returns HRDATA=0xCAFE_0001 (HRESP=0) with a
//              clean STATUS=0x0000_0001, proving data integrity and recovery.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the error-response-window timing sequence. Scoreboard
//              enabled so address propagation and response checks run
//              automatically (VG1, VG2, VG3, VG4, VG5, VG6).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_014 — error category, error_response_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_014 extends uvm_test;

  `uvm_component_utils(test_error_014)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_014", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so address propagation / responses are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_014: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_014: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the error-response-window timing / recovery flow ───────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_014_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_014: starting");

    `uvm_info("ERR014", "========== TEST_ERROR_014 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the error-response-window timing / recovery flow
    ahb_seq = ahb_mst_test_error_014_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR014", "========== TEST_ERROR_014 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_014: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR014", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR014",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_014
