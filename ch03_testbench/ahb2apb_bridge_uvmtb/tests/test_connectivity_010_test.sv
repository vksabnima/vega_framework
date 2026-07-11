// =============================================================================
// FILE: tests/test_connectivity_010_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CONNECTIVITY_010 (presetn_reset_connectivity)
// DESCRIPTION: Verifies PRESETn forces the peripheral-side outputs to their
//              defined reset values (PSEL=0, PENABLE=0, PADDR=0x0000_0000,
//              PWDATA=0x0000_0000 per Table 8) and that the interface recovers
//              after PRESETn deassertion. After reset deasserts and the
//              interface returns to idle, a fresh source write is driven to
//              HADDR=0x0000_4000 (HWDATA=0xCAFE_F00D); the bridge maps it to a
//              peripheral write that steps SETUP (PSEL=1, PENABLE=0) -> ACTIVE
//              (PSEL=1, PENABLE=1) with PADDR=0x0000_4000 and PWDATA=0xCAFE_F00D,
//              proving normal operation resumes and PRESETn connectivity holds.
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              connectivity sequence. Scoreboard enabled so the reset-value and
//              post-reset recovery checks are exercised.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_010 — connectivity category,
//     peripheral_side_interface_signals (pages page 8).
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_connectivity_010 extends uvm_test;

  `uvm_component_utils(test_connectivity_010)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_connectivity_010", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the PRESETn reset-value and recovery checks run.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single post-reset recovery write

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_010: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_010: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive PRESETn reset connectivity stimulus ──────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_connectivity_010_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_connectivity_010: starting");

    `uvm_info("CONN010", "========== TEST_CONNECTIVITY_010 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the PRESETn reset connectivity stimulus on AHB. PRESETn assertion
    // and reset-value sampling are handled by tb_top's reset and the monitors;
    // this sequence drives the post-reset recovery write.
    ahb_seq = ahb_mst_test_connectivity_010_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the recovery transaction to progress through the bridge
    // FSM and be captured by both monitors before the test ends.
    #200ns;

    `uvm_info("CONN010", "========== TEST_CONNECTIVITY_010 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_connectivity_010: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("CONN010", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("CONN010",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_connectivity_010
