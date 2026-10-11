// =============================================================================
// FILE: tests/test_error_003_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_003 (addr_error_read_direction_context_capture)
// DESCRIPTION: Verifies invalid-address READ detection and read-direction
//              context capture: a good read at 0x0000_3000 completes cleanly
//              (HRDATA=0x5555_AAAA, HRESP=0), then an invalid-range READ at
//              0xBEEF_0000 sets ADDR_ERR, returns an HRESP error, asserts the
//              sticky ERR_INT (ERR_INT_EN=1), and captures ERROR_ADDR=0xBEEF_0000
//              with ERROR_INFO recording direction=read. HRDATA is not presented
//              as valid (no target access launched). The model then recovers via
//              W1C + soft-reset (preserving config) and a post-recovery read at
//              0x0000_4000 returns 0x0F0F_F0F0 with a clean error log.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the error sequence. Scoreboard enabled so address
//              propagation and error-response checks run automatically
//              (VG1, VG3, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_003 — error category, address_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_003 extends uvm_test;

  `uvm_component_utils(test_error_003)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_003", uvm_component parent);
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
      `uvm_fatal("NOVIF", "test_error_003: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_003: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the read-direction address-error / recovery flow ──────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_003_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_003: starting");

    `uvm_info("ERR003", "========== TEST_ERROR_003 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the read-direction address-error detection / capture / recovery flow
    ahb_seq = ahb_mst_test_error_003_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR003", "========== TEST_ERROR_003 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_003: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR003", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR003",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_003
