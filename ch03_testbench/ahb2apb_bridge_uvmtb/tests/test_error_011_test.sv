// =============================================================================
// FILE: tests/test_error_011_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_011 (target_error_sticky_persistence_no_clear)
// DESCRIPTION: Verifies the sticky behavior of STATUS.PSLVERR after a target
//              error — the flag persists across subsequent good (non-error)
//              traffic and is only removed by W1C / soft reset. With CTRL
//              programmed for ENABLE=1 (0x0000_0001, ERR_INT_EN=0), a good write
//              at 0x0000_6000 (PWDATA=0xA5A5_0001) completes OKAY with a clean
//              STATUS. An injected write at 0x0000_6010 with PSLVERR=1 at the
//              target active phase fires the error: HRESP=1, STATUS sets PSLVERR
//              b5=1 (sticky) while ERR_INT stays 0 (STATUS=0x0000_0021). The
//              error log captures ERROR_ADDR=0x0000_6010 and ERROR_INFO
//              (direction=write, class=target-error). A subsequent good write at
//              0x0000_6020 completes (HRESP=0) but must NOT auto-clear the sticky
//              PSLVERR (STATUS stays 0x0000_0021). W1C of bit 5 (STATUS=
//              0x0000_0020) clears PSLVERR (STATUS=0x0000_0001) while
//              ERROR_ADDR/ERROR_INFO are retained (RO); SOFT_RST (CTRL=
//              0x0000_0003) clears the error log and self-clears (CTRL=
//              0x0000_0001). A post-recovery good write + read-back at 0x0000_7000
//              proves data integrity (0xC0DE_0004) with a clean STATUS=
//              0x0000_0001.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the sticky-persistence sequence. Scoreboard enabled so
//              address propagation and response checks run automatically
//              (VG1, VG2, VG3, VG4, VG5, VG6).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_011 — error category, target_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_011 extends uvm_test;

  `uvm_component_utils(test_error_011)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_011", uvm_component parent);
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
      `uvm_fatal("NOVIF", "test_error_011: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_011: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the sticky-persistence error capture flow ──────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_011_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_011: starting");

    `uvm_info("ERR011", "========== TEST_ERROR_011 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the sticky-persistence error capture flow
    ahb_seq = ahb_mst_test_error_011_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR011", "========== TEST_ERROR_011 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_011: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR011", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR011",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_011
