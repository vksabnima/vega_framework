// =============================================================================
// FILE: tests/test_main_datapath_010_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_MAIN_DATAPATH_010 (single_wait_state_delays_completion)
// DESCRIPTION: Drives a single accepted AHB word write (HADDR=0x0000_1000,
//              HWDATA=0xDEAD_BEEF) and verifies that a single PREADY=0 wait
//              state holds the APB transfer in the ACTIVE phase and delays
//              HREADY_OUT to the source side: PENABLE stays 1 throughout the
//              stall, PADDR/PWDATA stay stable during the wait, HREADY_OUT is 0
//              for every PREADY=0 cycle and pulses 1 only when PREADY=1, and the
//              transfer completes cleanly with HRESP=0 (VG1/VG2/VG4/VG6).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              main-datapath sequence. Scoreboard enabled so the HADDR->PADDR
//              propagation, write direction (PWRITE=1) and HWDATA->PWDATA
//              mapping are checked for the transfer.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_010 — main_datapath category,
//     back_pressure_wait_behavior.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_main_datapath_010 extends uvm_test;

  `uvm_component_utils(test_main_datapath_010)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_main_datapath_010", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so HADDR->PADDR propagation, the write direction
    // (PWRITE=1) and the HWDATA->PWDATA data mapping are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single accepted write exercising the wait state

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_010: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_main_datapath_010: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive one accepted write and observe the wait-state stall ────
  task run_phase(uvm_phase phase);
    ahb_mst_test_main_datapath_010_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_main_datapath_010: starting");

    `uvm_info("DP010", "========== TEST_MAIN_DATAPATH_010 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the single accepted write on AHB
    ahb_seq = ahb_mst_test_main_datapath_010_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the write (and its wait state) to propagate through
    // the bridge.
    #200ns;

    `uvm_info("DP010", "========== TEST_MAIN_DATAPATH_010 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_main_datapath_010: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("DP010", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("DP010",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_main_datapath_010
