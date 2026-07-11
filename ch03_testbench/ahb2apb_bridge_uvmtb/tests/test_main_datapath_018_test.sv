// =============================================================================
// FILE: tests/test_main_datapath_018_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_018 (read_data_not_returned_on_target_error)
// DESCRIPTION: Drives a single accepted AHB word READ to 0x0000_4000 whose APB
//              target access returns PSLVERR=1 during the active phase, then
//              reads back the control/status block. Verifies that the read-data
//              return path reflects the error: the bridge returns HRESP=1
//              (ERROR) to the source rather than delivering valid OKAY data, the
//              STATUS sticky PSLVERR bit (0xF04) is set, and ERROR_ADDR (0xF08)
//              captures 0x0000_4000 (VG5/VG3).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the target-error ->
//              source-error (PSLVERR -> HRESP) propagation is checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_018 — main_datapath category,
//     read_data_return_path.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_018 extends uvm_test;

  `uvm_component_utils(test_main_datapath_018)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_018", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the target-error -> source-error (PSLVERR -> HRESP)
    // propagation and the sticky STATUS/ERROR_ADDR capture are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // one accepted errored read under test (+ register accesses)

    // Inject a PSLVERR target error on the read address under test.
    cfg.add_apb_err_addr(32'h0000_4000);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_018: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_018: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the errored read and observe HRESP=1 / sticky STATUS ───
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_018_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_018: starting");

    `uvm_info("DP018", "========== TEST_MAIN_DATAPATH_018 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the errored read + register read-back on AHB
    ahb_seq = ahb_mst_test_main_datapath_018_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge and
    // be captured by both monitors.
    #200ns;

    `uvm_info("DP018", "========== TEST_MAIN_DATAPATH_018 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_018: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP018", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP018",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_018
