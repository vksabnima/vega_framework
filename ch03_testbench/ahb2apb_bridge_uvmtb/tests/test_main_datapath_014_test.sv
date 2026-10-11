// =============================================================================
// FILE: tests/test_main_datapath_014_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_014 (basic_single_read_data_return)
// DESCRIPTION: Verifies a single (non-sequence) HTRANS=NONSEQ word read returns
//              PRDATA on HRDATA only after the target-side active phase completes
//              (PREADY=1). Drives HADDR=0x0000_1000 and confirms the read data
//              returned from APB reaches the AHB master unchanged at completion
//              (VG3/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the main-datapath read sequence. Scoreboard enabled so the
//              PRDATA->HRDATA return path and the one-to-one transaction count
//              are checked automatically.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_014 — main_datapath category, read data return path.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_014 extends uvm_test;

  `uvm_component_utils(test_main_datapath_014)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_014", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the PRDATA->HRDATA return path and the one-to-one
    // transaction mapping are checked (VG3/VG4/VG6).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single baseline NONSEQ word read

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_014: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_014: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive single NONSEQ word read (data return) ───────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_014_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_014: starting");

    `uvm_info("DP014", "========== TEST_MAIN_DATAPATH_014 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the single baseline NONSEQ word read on AHB
    ahb_seq = ahb_mst_test_main_datapath_014_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transaction to propagate through the bridge.
    #200ns;

    `uvm_info("DP014", "========== TEST_MAIN_DATAPATH_014 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_014: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP014", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP014",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_014
