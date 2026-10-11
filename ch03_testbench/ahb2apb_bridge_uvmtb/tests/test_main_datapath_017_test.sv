// =============================================================================
// FILE: tests/test_main_datapath_017_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_017 (read_data_address_range_correlation)
// DESCRIPTION: Drives three accepted AHB word READs spanning the 32-bit address
//              range (HADDR=0x0000_0000 / 0x8000_0000 / 0xFFFF_FFFC) and verifies
//              the read data returned on HRDATA correlates with the correct target
//              address with no cross-contamination: each returned HRDATA must
//              equal the PRDATA driven at that address's target access
//              (0x1111_1111 / 0x2222_2222 / 0x3333_3333) with PADDR mirroring
//              HADDR and HRESP=0 for all three (VG1/VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR
//              propagation, read direction (PWRITE=0) and per-address
//              PRDATA->HRDATA mapping are checked for each transfer.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_017 — main_datapath category,
//     read_data_return_path.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_017 extends uvm_test;

  `uvm_component_utils(test_main_datapath_017)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_017", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR propagation, the read direction
    // (PWRITE=0) and the per-address PRDATA->HRDATA data mapping are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // three accepted reads (low/mid/high address)

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_017: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_017: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive three reads and observe address-correlated HRDATA ──────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_017_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_017: starting");

    `uvm_info("DP017", "========== TEST_MAIN_DATAPATH_017 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the three accepted reads on AHB
    ahb_seq = ahb_mst_test_main_datapath_017_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the reads to propagate through the bridge and be
    // captured by both monitors.
    #200ns;

    `uvm_info("DP017", "========== TEST_MAIN_DATAPATH_017 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_017: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP017", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP017",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_017
