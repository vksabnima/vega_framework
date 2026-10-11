// =============================================================================
// FILE: tests/test_main_datapath_006_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_006 (basic_read_translation_and_verify)
// DESCRIPTION: Verifies a single source-side read (HADDR=0x0000_2000) translates
//              1:1 to a target-side read access (PADDR=0x0000_2000, PWRITE=0) and
//              that HRDATA reflects PRDATA (0xCAFE_F00D) only after target-side
//              completion (PREADY=1 active phase, HRESP=0). The target location
//              is primed first so the memory-model APB slave returns the expected
//              PRDATA deterministically (VG1/VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR
//              propagation, read direction (PWRITE=0) and PRDATA->HRDATA mapping
//              are checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_006 — main_datapath category, core_translation_behavior.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_006 extends uvm_test;

  `uvm_component_utils(test_main_datapath_006)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_006", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR propagation, the read direction
    // (PWRITE=0) and the PRDATA->HRDATA read-data mapping are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // prime write + single read under test

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_006: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_006: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive prime write then single read translation ─────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_006_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_006: starting");

    `uvm_info("DP006", "========== TEST_MAIN_DATAPATH_006 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the prime write then the single read translation on AHB
    ahb_seq = ahb_mst_test_main_datapath_006_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the read transfer to propagate through the bridge.
    #200ns;

    `uvm_info("DP006", "========== TEST_MAIN_DATAPATH_006 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_006: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP006", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP006",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_006
