// =============================================================================
// FILE: tests/test_register_access_007_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_007 (ctrl_soft_rst_self_clearing_action)
// DESCRIPTION: Verifies that writing the SOFT_RST bit in CTRL triggers a soft
//              reset that clears the sticky STATUS error flags while preserving
//              the CTRL configuration bits, and that SOFT_RST self-clears.
//
//              Preconditions: PCLK/HCLK running, PRESETn deasserted, STATUS
//              (0x0000_0F04) has sticky error bit(s) set from a prior scenario.
//
//              The register-access sequence drives:
//                1. READ  STATUS @0x0F04 — sticky bit5 PSLVERR=1 pre-reset.
//                2. WRITE CTRL   @0x0F00 = 0x0000_0003 (ENABLE=1, SOFT_RST=1).
//                3. READ  STATUS @0x0F04 — sticky bits 7,6,5,4 cleared, READY=1.
//                4. READ  CTRL   @0x0F00 — ENABLE=1 preserved, SOFT_RST=0.
//              The scoreboard checks transfer propagation HADDR->PADDR,
//              HWDATA->PWDATA and HRDATA<-PRDATA.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_007 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, CTRL soft-reset write then read-back.
// =============================================================================

class test_register_access_007 extends uvm_test;

  `uvm_component_utils(test_register_access_007)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_007", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the transfer propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 4;  // STATUS read, CTRL write, STATUS read, CTRL read

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_007: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_007: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: STATUS read, CTRL soft-reset write, STATUS read, CTRL read ──
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_007_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_007: starting");

    `uvm_info("REGACC007", "========== TEST_REGISTER_ACCESS_007 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the CTRL soft-reset stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_007_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transfers to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC007", "========== TEST_REGISTER_ACCESS_007 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_007: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC007", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC007",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_007
