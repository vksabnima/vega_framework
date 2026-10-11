// =============================================================================
// FILE: tests/test_connectivity_006_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CONNECTIVITY_006 (paddr_address_bus_connectivity)
// DESCRIPTION: Verifies PADDR drives both the minimum (0x0000_0000) and the
//              maximum (0xFFFF_FFFF) address values correctly through the
//              peripheral-side interface. Two source-side write transfers are
//              driven; the scoreboard confirms PADDR matches the captured
//              source HADDR for each (PSEL=1/PENABLE=0 in SETUP, PSEL=1/
//              PENABLE=1 in ACTIVE) with no PADDR bit stuck/tied.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the connectivity sequence. Scoreboard enabled so the
//              PADDR==HADDR comparison is checked.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_006 — connectivity category,
//     peripheral_side_interface_signals (pages page 8).
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_connectivity_006 extends uvm_test;

  `uvm_component_utils(test_connectivity_006)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_connectivity_006", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the PADDR==HADDR connectivity comparison is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // min-address write + max-address write

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_006: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_006: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive min/max PADDR connectivity stimulus ──────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_connectivity_006_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_connectivity_006: starting");

    `uvm_info("CONN006", "========== TEST_CONNECTIVITY_006 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the PADDR min/max address connectivity stimulus on AHB
    ahb_seq = ahb_mst_test_connectivity_006_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the last transaction to progress through the bridge FSM
    // and be captured by both monitors before the test ends.
    #200ns;

    `uvm_info("CONN006", "========== TEST_CONNECTIVITY_006 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_connectivity_006: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("CONN006", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("CONN006",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_connectivity_006
