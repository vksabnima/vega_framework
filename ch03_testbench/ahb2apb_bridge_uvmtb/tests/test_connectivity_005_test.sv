// =============================================================================
// FILE: tests/test_connectivity_005_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CONNECTIVITY_005 (source_reset_connectivity)
// DESCRIPTION: Verifies HRESETn is connected by asserting reset and confirming
//              all source-side and peripheral-side outputs assume their
//              documented reset values (Table 8): HREADY_OUT=1, HRESP=0,
//              HRDATA=0, PSEL=0, PENABLE=0, PADDR=0, PWDATA=0. After HRESETn
//              deasserts, the example registers read their reset values
//              (CTRL=0x1, STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0) and a
//              new transfer to HADDR=0x0000_4000 proves normal operation
//              resumes (FLOW-1).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the connectivity sequence. Scoreboard enabled so the
//              post-reset register reads and resume transfer are checked.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_005 — connectivity category, source_side_interface_signals.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_connectivity_005 extends uvm_test;

  `uvm_component_utils(test_connectivity_005)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_connectivity_005", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the post-reset register reads + resume transfer are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 5;  // 4 register reads + 1 resume write

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_005: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_005: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive post-reset register reads + resume transfer ──────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_connectivity_005_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_connectivity_005: starting");

    `uvm_info("CONN005", "========== TEST_CONNECTIVITY_005 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the source-side reset-connectivity stimulus on AHB
    ahb_seq = ahb_mst_test_connectivity_005_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the last transaction to progress through the bridge FSM
    // and be captured by both monitors before the test ends.
    #200ns;

    `uvm_info("CONN005", "========== TEST_CONNECTIVITY_005 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_connectivity_005: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("CONN005", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("CONN005",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_connectivity_005
