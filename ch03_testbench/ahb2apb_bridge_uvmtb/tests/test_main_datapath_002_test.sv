// =============================================================================
// FILE: tests/test_main_datapath_002_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_002 (sequential_burst_address_increment_word)
// DESCRIPTION: Verifies an incrementing multi-transfer sequence (NONSEQ then SEQ)
//              with HSIZE=word produces target addresses advancing by 0x4 per
//              beat, handled in-order. Drives an INCR4 word-write burst across
//              HADDR=0x0000_2000..0x0000_200C with HWDATA 0x1111_1111..0x4444_4444
//              and confirms the bridge re-drives them onto PADDR/PWDATA in order
//              (VG1/VG2/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR /
//              HWDATA->PWDATA propagation and one-to-one beat ordering are checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_002 — main_datapath category, sequence_handling.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_002 extends uvm_test;

  `uvm_component_utils(test_main_datapath_002)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_002", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR / HWDATA->PWDATA and the in-order beat
    // mapping are checked (VG1/VG2/VG4/VG6).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 4;  // four-beat INCR4 word-write burst

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_002: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_002: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive incrementing INCR4 word-write burst ─────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_002_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_002: starting");

    `uvm_info("DP002", "========== TEST_MAIN_DATAPATH_002 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the incrementing NONSEQ/SEQ word-write burst on AHB
    ahb_seq = ahb_mst_test_main_datapath_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the final beat to propagate through the bridge.
    #200ns;

    `uvm_info("DP002", "========== TEST_MAIN_DATAPATH_002 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_002: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP002", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP002",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_002
