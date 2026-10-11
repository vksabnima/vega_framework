// =============================================================================
// FILE: tests/test_error_010_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_010 (target_error_during_read_access)
// DESCRIPTION: Verifies a target error injected on a READ transfer is captured
//              with read direction in ERROR_INFO, HRDATA is NOT treated as a
//              valid completion, and recovery restores clean operation. With CTRL
//              programmed for ENABLE=1 + ERR_INT_EN=1 (0x0000_0009), a good read
//              at 0x0000_4000 returns HRDATA=0x1234_5678 (HRESP=0, HREADY_OUT=1)
//              with a clean STATUS. An injected read at 0x0000_4004 with PSLVERR=1
//              at the target active phase (garbage PRDATA=0xFFFF_FFFF) fires the
//              error: HRESP=1, the read data is discarded, STATUS sets PSLVERR
//              b5=1 (sticky) and ERR_INT b7=1 (STATUS=0x0000_00A1). The error log
//              captures ERROR_ADDR=0x0000_4004 and ERROR_INFO (direction=read,
//              class=target-error). The interrupt clears via W1C (STATUS=
//              0x0000_0080 -> 0x0000_0021), recovery clears sticky PSLVERR
//              (STATUS=0x0000_0020) and SOFT_RST (CTRL=0x0000_000B) clears the
//              error log and preserves config, and a post-recovery good read at
//              0x0000_5000 proves data integrity (HRDATA=0x0BADF00D, HRESP=0)
//              with a clean STATUS=0x0000_0009.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the target-error-on-read sequence. Scoreboard enabled so
//              address propagation and response checks run automatically
//              (VG1, VG2, VG3, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_010 — error category, target_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_010 extends uvm_test;

  `uvm_component_utils(test_error_010)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_010", uvm_component parent);
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
      `uvm_fatal("NOVIF", "test_error_010: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_010: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the target-error-on-read capture flow ──────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_010_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_010: starting");

    `uvm_info("ERR010", "========== TEST_ERROR_010 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the target-error-on-read capture flow
    ahb_seq = ahb_mst_test_error_010_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR010", "========== TEST_ERROR_010 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_010: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR010", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR010",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_010
