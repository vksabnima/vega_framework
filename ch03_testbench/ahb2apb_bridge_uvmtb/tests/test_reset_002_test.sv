// =============================================================================
// FILE: tests/test_reset_002_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_RESET_002 (soft_reset_clears_sticky_status_flags)
// DESCRIPTION: Verifies that asserting SOFT_RST clears sticky STATUS error
//              flags (ERR_INT b7, PSLVERR b5) that were set by an injected
//              target error, returns STATUS to its reset value 0x1, clears the
//              ERROR_ADDR/ERROR_INFO debug-capture registers to 0x0, and that
//              after clearing SOFT_RST the model fully recovers (write
//              0xCAFEBABE reads back as 0xCAFEBABE with no new errors).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the reset sequence. Scoreboard enabled so address
//              propagation and data integrity checks run automatically.
//
// DERIVED FROM:
//   - XTP TEST_RESET_002 — reset category, soft_reset feature (pages 11-12).
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_reset_002 extends uvm_test;

  `uvm_component_utils(test_reset_002)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_reset_002", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so address propagation / data integrity are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_reset_002: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_reset_002: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the soft-reset sticky-flag clear / recovery flow ──────
  task run_phase(uvm_phase phase);
    ahb_mst_test_reset_002_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_reset_002: starting");

    `uvm_info("RST002", "========== TEST_RESET_002 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the soft-reset sticky-flag clear / recovery stimulus on AHB
    ahb_seq = ahb_mst_test_reset_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("RST002", "========== TEST_RESET_002 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_reset_002: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("RST002", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("RST002",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_reset_002
