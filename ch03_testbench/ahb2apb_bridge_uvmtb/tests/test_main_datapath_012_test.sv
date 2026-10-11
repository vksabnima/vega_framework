// =============================================================================
// FILE: tests/test_main_datapath_012_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_012 (back_to_back_writes_with_stall_data_patterns)
// DESCRIPTION: Drives three consecutive accepted AHB word WRITES carrying the
//              data-integrity patterns all 1s (0xFFFF_FFFF @ 0x3000), all 0s
//              (0x0000_0000 @ 0x3004) and alternating (0xAAAA_5555 @ 0x3008),
//              each whose APB ACTIVE phase is held by PREADY=0 back-pressure, then
//              reads the three addresses back. Verifies that PWDATA is held stable
//              throughout each stall, HREADY_OUT is low during the stall and high
//              at completion for every write, and that each pattern round-trips
//              unchanged (VG1/VG2/VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so HADDR->PADDR
//              propagation, write direction (PWRITE=1), HWDATA->PWDATA and the
//              read-back data mapping are checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_012 — main_datapath category,
//     back_pressure_wait_behavior.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_012 extends uvm_test;

  `uvm_component_utils(test_main_datapath_012)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_012", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR propagation, the write direction
    // (PWRITE=1), the HWDATA->PWDATA mapping and the read-back data are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // three back-to-back writes (then three read-backs)

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_012: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_012: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive three stalled writes + read-back ───────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_012_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_012: starting");

    `uvm_info("DP012", "========== TEST_MAIN_DATAPATH_012 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the three stalled writes + read-back on AHB
    ahb_seq = ahb_mst_test_main_datapath_012_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the writes (and their wait states) plus the read-back
    // to propagate through the bridge.
    #200ns;

    `uvm_info("DP012", "========== TEST_MAIN_DATAPATH_012 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_012: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP012", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP012",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_012
