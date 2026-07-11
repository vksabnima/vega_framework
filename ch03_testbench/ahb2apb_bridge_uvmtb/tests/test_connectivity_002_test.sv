// =============================================================================
// FILE: tests/test_connectivity_002_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_CONNECTIVITY_002 (source_write_data_bus_connectivity)
// DESCRIPTION: Verifies the HWDATA write data bus is fully connected by driving
//              walking/boundary data patterns (0xFFFF_FFFF, 0x0000_0000,
//              0xAAAA_AAAA) and confirming the bridge captures and propagates
//              them unchanged onto PWDATA (VG2 — write-data propagation, no
//              stuck/shorted data bits).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the connectivity sequence. Scoreboard enabled so the
//              HWDATA->PWDATA comparison is checked automatically (VG2).
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_002 — connectivity category.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled for VG2.
// =============================================================================

class test_connectivity_002 extends uvm_test;

  `uvm_component_utils(test_connectivity_002)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_connectivity_002", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HWDATA->PWDATA propagation is checked (VG2).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // three data patterns: 0xF..F, 0x0..0, 0xA..A

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_002: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_connectivity_002: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive boundary write-data patterns ────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_connectivity_002_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_connectivity_002: starting");

    `uvm_info("CONN002", "========== TEST_CONNECTIVITY_002 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the boundary HWDATA connectivity stimulus on AHB
    ahb_seq = ahb_mst_test_connectivity_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("CONN002", "========== TEST_CONNECTIVITY_002 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_connectivity_002: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("CONN002", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("CONN002",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_connectivity_002
