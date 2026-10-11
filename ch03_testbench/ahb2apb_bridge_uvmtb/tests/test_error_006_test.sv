// =============================================================================
// FILE: tests/test_error_006_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_006 (timeout_disabled_no_error)
// DESCRIPTION: Negative / control test verifying that with TIMEOUT_EN=0 a
//              prolonged PREADY=0 stall does NOT set TIMEOUT_ERR or HRESP, but
//              instead holds completion until the target finally responds. With
//              CTRL programmed for TIMEOUT_EN=0 (0x0000_0071), a good read at
//              0x0000_1000 returns 0xA5A5_A5A5 cleanly (HRESP=0, clean STATUS),
//              then a write at 0x0000_4000 (0x0000_BEEF) with the target stalled
//              (PREADY held 0 well past the TIMEOUT_VAL window) does NOT trigger
//              a timeout: HRESP stays 0, HREADY_OUT stays 0 (BUSY=1),
//              TIMEOUT_ERR (STATUS bit6) and ERR_INT (bit7) stay 0, and
//              ERROR_ADDR/ERROR_INFO remain 0. Once PREADY is released the held
//              write completes OKAY (PADDR=0x0000_4000, PWDATA=0x0000_BEEF,
//              HRESP=0, BUSY=0). The model is then soft-reset for hygiene
//              (config preserved, error log clean), reconfigured, and a
//              post-recovery good write at 0x0000_5000 (0x0BAD_F00D) completes
//              OKAY with a clean STATUS.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the timeout-disabled sequence. Scoreboard enabled so
//              address propagation and response checks run automatically
//              (VG1, VG2, VG3, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_006 — error category, timeout_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_006 extends uvm_test;

  `uvm_component_utils(test_error_006)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_006", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so address propagation / responses are checked.
    // Timeout is DISABLED in this test, so the stalled write is eventually
    // released and completes normally (a clean APB transaction to pair).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Stall the APB slave at the target address; with TIMEOUT_EN=0 the bridge
    // holds the transfer (no timeout) until the slave releases PREADY.
    cfg.add_apb_stall_addr(32'h0000_4000);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_006: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_006: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the timeout-disabled / no-error flow ───────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_006_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_006: starting");

    `uvm_info("ERR006", "========== TEST_ERROR_006 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the timeout-disabled / no-error flow
    ahb_seq = ahb_mst_test_error_006_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR006", "========== TEST_ERROR_006 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_006: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR006", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR006",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_006
