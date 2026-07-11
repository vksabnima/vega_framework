// =============================================================================
// FILE: tests/test_bringup_init_001_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_BRINGUP_INIT_001 (single_clock_domain_reset_bringup)
// DESCRIPTION: Verifies that with PCLK tied to HCLK in a single clock domain,
//              the bridge initializes to the documented clean idle reset state.
//              After reset deassertion, reads back the reset-state registers
//              (CTRL/STATUS/ERROR_ADDR/ERROR_INFO) through the AHB master.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the bringup-init sequence.
//
// DERIVED FROM:
//   - XTP TEST_BRINGUP_INIT_001 — bringup_init category.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard disabled (bringup).
// =============================================================================

class test_bringup_init_001 extends uvm_test;

  `uvm_component_utils(test_bringup_init_001)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_bringup_init_001", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Bringup-style reset check — no scoreboard checking required.
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 4;  // CTRL, STATUS, ERROR_ADDR, ERROR_INFO

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_bringup_init_001: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_bringup_init_001: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: read back reset-state registers ───────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_bringup_init_001_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_bringup_init_001: starting");

    `uvm_info("INIT001", "========== TEST_BRINGUP_INIT_001 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the reset-state register read-back stimulus on AHB
    ahb_seq = ahb_mst_test_bringup_init_001_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("INIT001", "========== TEST_BRINGUP_INIT_001 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_bringup_init_001: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("INIT001", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("INIT001",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_bringup_init_001
