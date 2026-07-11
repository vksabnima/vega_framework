// =============================================================================
// FILE: tests/test_connectivity_001_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CONNECTIVITY_001 (source_address_bus_connectivity)
// DESCRIPTION: Verifies the HADDR address bus is fully connected by driving the
//              minimum (0x0000_0000) and maximum (0xFFFF_FFFF) address values
//              and confirming the bridge captures and translates them onto
//              PADDR (VG1 — address propagation, no stuck/swapped bits).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the connectivity sequence. Scoreboard enabled so the
//              HADDR->PADDR comparison is checked automatically (VG1).
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_001 — connectivity category.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled for VG1.
// =============================================================================

class test_connectivity_001 extends uvm_test;

  `uvm_component_utils(test_connectivity_001)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_connectivity_001", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR propagation is checked (VG1).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // two address corners: 0x0000_0000 and 0xFFFF_FFFF

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_001: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_001: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive min/max address corners ─────────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_connectivity_001_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_connectivity_001: starting");

    `uvm_info("CONN001", "========== TEST_CONNECTIVITY_001 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the min/max HADDR connectivity stimulus on AHB
    ahb_seq = ahb_mst_test_connectivity_001_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("CONN001", "========== TEST_CONNECTIVITY_001 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_connectivity_001: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("CONN001", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("CONN001",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_connectivity_001
