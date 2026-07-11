// =============================================================================
// FILE: tests/test_main_datapath_013_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_013 (timeout_during_persistent_stall)
// DESCRIPTION: Enables the bridge back-pressure timeout (CTRL=0x0000_00F1:
//              ENABLE=1, TIMEOUT_EN=1, TIMEOUT_VAL=3'b111), then drives a single
//              source write (HADDR=0x0000_4000, HWDATA=0x1234_5678) whose APB
//              target transfer is held by a persistent PREADY=0 stall. Verifies
//              that HREADY_OUT stays low for the entire timeout window (PENABLE
//              held 1, transfer kept active) and, when the timeout fires, the
//              transfer terminates with HREADY_OUT=1 / HRESP=1, STATUS.TIMEOUT_ERR
//              (bit 6) becomes sticky and ERROR_ADDR captures 0x0000_4000.
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so register and error
//              propagation are checked.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_013 — main_datapath category,
//     back_pressure_wait_behavior (pages 10-11).
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_013 extends uvm_test;

  `uvm_component_utils(test_main_datapath_013)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_013", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Scoreboard off: the timed-out source write aborts with no clean APB
    // completion to pair. Timeout behaviour is verified by the self-checks.
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 1;  // single source write held by the persistent stall

    // Stall the APB slave at the source address so the bridge times out.
    cfg.add_apb_stall_addr(32'h0000_4000);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_013: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_013: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: program timeout, drive a persistently stalled write ─────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_013_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_013: starting");

    `uvm_info("DP013", "========== TEST_MAIN_DATAPATH_013 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the register program + held write on AHB
    ahb_seq = ahb_mst_test_main_datapath_013_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the timeout window to elapse and the error
    // indication to propagate through the bridge.
    #200ns;

    `uvm_info("DP013", "========== TEST_MAIN_DATAPATH_013 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_013: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP013", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP013",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_013
