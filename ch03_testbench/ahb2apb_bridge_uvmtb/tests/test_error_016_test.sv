// =============================================================================
// FILE: tests/test_error_016_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_016 (back_to_back_error_then_normal_no_stale_state)
// DESCRIPTION: Verifies a target error transfer immediately followed (after a
//              full clear) by a normal transfer produces no stale HRESP or stale
//              sticky bits — proving error response window isolation. With CTRL
//              programmed for ENABLE=1 (0x0000_0001), a good write at 0x0000_4000
//              (PWDATA=0x0000_9999) completes OKAY (PSEL=1, PENABLE=1, HREADY_OUT=1,
//              HRESP=0) with a clean STATUS=0x0000_0001. An injected read at
//              0x0000_4100 with PSLVERR=1, PREADY=1, PRDATA=0xFFFF_FFFF sampled at
//              the T3 active phase fires the error: HRESP=1 asserted only within
//              its error response window (T4..T6) with HREADY_OUT=1 at window
//              close, and HRDATA not consumed (error path). STATUS=0x0000_0021
//              (PSLVERR b5=1, READY b0=1), ERR_INT b7=0 (ERR_INT_EN disabled),
//              ERROR_ADDR=0x0000_4100, ERROR_INFO direction=read. W1C of bit 5
//              (STATUS=0x0000_0020) clears it (STATUS=0x0000_0001); SOFT_RST
//              (CTRL=0x0000_0003) fully clears active state + error log (PSEL=0,
//              PENABLE=0, HRESP=0, HREADY_OUT=1; STATUS=0x0000_0001, ERROR_ADDR=0,
//              ERROR_INFO=0). After reconfigure (CTRL=0x0000_0001), a post-recovery
//              good read at the SAME address class 0x0000_4100 returns
//              HRDATA=0x1357_9BDF with HRESP=0 (no stale error leakage) and a clean
//              STATUS=0x0000_0001 / ERROR_ADDR=0x0000_0000 error log, proving data
//              integrity and no stale state.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the back-to-back error-then-normal sequence. Scoreboard
//              enabled so address propagation and response checks run
//              automatically (VG1, VG2, VG3, VG4, VG5, VG6).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_016 — error category, error_response_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_016 extends uvm_test;

  `uvm_component_utils(test_error_016)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_016", uvm_component parent);
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
      `uvm_fatal("NOVIF", "test_error_016: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_016: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the back-to-back error-then-normal / no-stale-state flow ─
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_016_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_016: starting");

    `uvm_info("ERR016", "========== TEST_ERROR_016 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the back-to-back error-then-normal / no-stale-state flow
    ahb_seq = ahb_mst_test_error_016_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR016", "========== TEST_ERROR_016 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_016: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR016", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR016",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_016
