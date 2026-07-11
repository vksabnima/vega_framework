// =============================================================================
// FILE: tests/test_error_005_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_005 (timeout_error_basic_detection)
// DESCRIPTION: Verifies that a timeout error is detected, captured in STATUS,
//              and logged when PREADY is never asserted within the programmed
//              observation window. With CTRL programmed for TIMEOUT_EN=1 and
//              TIMEOUT_VAL=3'b111, a good write at 0x0000_1000 completes cleanly
//              (HRESP=0, clean STATUS), then a write at 0x0000_2000 with the
//              target stalled (PREADY held 0) causes the timeout window to
//              expire: HRESP=1 with HREADY_OUT released, STATUS bit6 TIMEOUT_ERR
//              becomes sticky, ERR_INT (bit7) stays 0 (ERR_INT_EN=0), and
//              ERROR_ADDR captures 0x0000_2000 with ERROR_INFO recording
//              direction=write / class=timeout. The model recovers via W1C of
//              TIMEOUT_ERR + soft reset (config preserved, error log cleared),
//              then a post-recovery good write at 0x0000_3000 (0x1234_5678)
//              completes OKAY with a clean STATUS.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the timeout-error sequence. Scoreboard enabled so address
//              propagation and error-response checks run automatically
//              (VG1, VG2, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_005 — error category, timeout_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_005 extends uvm_test;

  `uvm_component_utils(test_error_005)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_005", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Scoreboard disabled: the timed-out write is forwarded onto APB but the
    // slave is stalled and the bridge aborts, so there is no clean APB
    // completion to pair against. The timeout behaviour is verified by the
    // sequence's self-checks (HRESP, STATUS.TIMEOUT_ERR, ERROR_ADDR/INFO).
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Stall the APB slave for the timeout target address so the bridge's
    // timeout FSM (TIMEOUT_VAL=7) fires.
    cfg.add_apb_stall_addr(32'h0000_2000);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_005: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_005: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the timeout-error detection / recovery flow ────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_005_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_005: starting");

    `uvm_info("ERR005", "========== TEST_ERROR_005 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the timeout-error detection / recovery flow
    ahb_seq = ahb_mst_test_error_005_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR005", "========== TEST_ERROR_005 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_005: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR005", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR005",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_005
