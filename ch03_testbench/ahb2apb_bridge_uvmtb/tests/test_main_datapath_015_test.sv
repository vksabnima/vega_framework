// =============================================================================
// FILE: tests/test_main_datapath_015_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_015 (read_data_blocked_until_target_completion)
// DESCRIPTION: Drives a single accepted AHB word READ (HADDR=0x0000_2000) and
//              verifies that HRDATA is NOT returned and source completion is
//              gated while the target is stalled (PREADY=0), then the correct
//              read data is returned once PREADY asserts: HREADY_OUT stays 0 and
//              HRDATA is not updated during the stall, HRDATA=0xA5A5_5A5A is
//              returned at completion with HRESP=0, and read data return strictly
//              follows target completion (VG1/VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR
//              propagation, read direction (PWRITE=0) and PRDATA->HRDATA mapping
//              are checked for the transfer.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_015 — main_datapath category,
//     read_data_return_path.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_015 extends uvm_test;

  `uvm_component_utils(test_main_datapath_015)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_015", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR propagation, the read direction
    // (PWRITE=0) and the PRDATA->HRDATA data mapping are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single accepted read exercising the stall

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_015: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_015: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive one accepted read and observe the gated completion ─────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_015_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_015: starting");

    `uvm_info("DP015", "========== TEST_MAIN_DATAPATH_015 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the single accepted read on AHB
    ahb_seq = ahb_mst_test_main_datapath_015_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the read (and its wait states) to propagate through
    // the bridge and be captured by both monitors.
    #200ns;

    `uvm_info("DP015", "========== TEST_MAIN_DATAPATH_015 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_015: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP015", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP015",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_015
