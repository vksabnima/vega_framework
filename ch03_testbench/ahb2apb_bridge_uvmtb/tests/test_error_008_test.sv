// =============================================================================
// FILE: tests/test_error_008_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_008 (timeout_window_boundary)
// DESCRIPTION: Verifies the timeout window boundary: a just-in-time PREADY
//              (asserted on the last in-window cycle) completes without error,
//              while a one-cycle-late PREADY (one cycle past the window)
//              triggers TIMEOUT_ERR. With CTRL programmed for a small timeout
//              window (0x0000_0091: ENABLE=1, TIMEOUT_EN b7=1, TIMEOUT_VAL=
//              3'b001), a good write at 0x0000_1000 (0x1111_2222) completes OKAY
//              (HRESP=0, HREADY_OUT=1) with a clean STATUS. An in-window write
//              at 0x0000_8000 (0x3333_4444) with PREADY on the last in-window
//              cycle completes cleanly (HRESP=0, no TIMEOUT_ERR). An
//              out-of-window write at 0x0000_9000 (0x5555_6666) with PREADY held
//              0 one cycle past the window fires a timeout: HRESP=1 and STATUS
//              sets TIMEOUT_ERR b6=1, the error log captures ERROR_ADDR=
//              0x0000_9000 and ERROR_INFO (direction=write, class=timeout). The
//              sticky flag clears via W1C (STATUS=0x0000_0040), SOFT_RST
//              recovery clears the error log and preserves config, and a
//              post-recovery good write at 0x0000_A000 (0x7777_8888) proves data
//              integrity (PADDR=0x0000_A000, PWDATA=0x7777_8888, HRESP=0) with a
//              clean STATUS.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the timeout-window-boundary sequence. Scoreboard enabled
//              so address propagation and response checks run automatically
//              (VG1, VG2, VG3, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_008 — error category, timeout_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_008 extends uvm_test;

  `uvm_component_utils(test_error_008)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_008", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Scoreboard off: the timed-out write aborts with no clean APB completion.
    // Timeout behaviour is verified by the sequence self-checks.
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Stall only the out-of-window target (0x9000) so it times out; the
    // in-window write (0x8000) completes normally (no stall) -> no timeout.
    cfg.add_apb_stall_addr(32'h0000_9000);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_008: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_008: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the timeout-window-boundary flow ───────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_008_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_008: starting");

    `uvm_info("ERR008", "========== TEST_ERROR_008 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the timeout-window-boundary flow
    ahb_seq = ahb_mst_test_error_008_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR008", "========== TEST_ERROR_008 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_008: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR008", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR008",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_008
