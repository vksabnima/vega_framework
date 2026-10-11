// =============================================================================
// FILE: tests/test_main_datapath_005_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_005 (basic_write_translation)
// DESCRIPTION: Verifies a single source-side write (HADDR=0x0000_1000,
//              HWDATA=0xDEAD_BEEF) is captured and translated 1:1 to a
//              target-side write (PADDR=0x0000_1000, PWDATA=0xDEAD_BEEF)
//              following the capture->setup->active->complete sequence, then
//              reads the same address back to confirm the stored data round-
//              trips unchanged on HRDATA (VG1/VG2/VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR /
//              HWDATA->PWDATA propagation and one-to-one mapping are checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_005 — main_datapath category, core_translation_behavior.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_005 extends uvm_test;

  `uvm_component_utils(test_main_datapath_005)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_005", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR / HWDATA->PWDATA propagation and the
    // 1:1 write translation plus read-back data integrity are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // single write + single read-back

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_005: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_005: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive single write translation then read-back ──────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_005_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_005: starting");

    `uvm_info("DP005", "========== TEST_MAIN_DATAPATH_005 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the single write translation then read-back on AHB
    ahb_seq = ahb_mst_test_main_datapath_005_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the read transfer to propagate through the bridge.
    #200ns;

    `uvm_info("DP005", "========== TEST_MAIN_DATAPATH_005 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_005: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP005", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP005",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_005
