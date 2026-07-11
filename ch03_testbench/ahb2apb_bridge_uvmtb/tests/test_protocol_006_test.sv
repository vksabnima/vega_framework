// =============================================================================
// FILE: tests/test_protocol_006_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_PROTOCOL_006 (wait_state_signal_stability_multi_wait)
// DESCRIPTION: Verifies that across SEVERAL consecutive PREADY=0 wait cycles the
//              bridge holds PSEL=1, PENABLE=1, PADDR=0x0000_2000 and PWRITE=0
//              stable while keeping HREADY_OUT deasserted. Drives one NONSEQ
//              read; the bridge progresses SETUP -> ACTIVE on the APB side and is
//              held across multiple wait cycles. On PREADY=1 (PRDATA=0x1234_5678)
//              the transfer completes: PSEL/PENABLE deassert, HREADY_OUT asserts,
//              HRDATA=0x1234_5678, HRESP=0 and STATUS.READY=1, BUSY=0.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the protocol sequence. Scoreboard enabled so the AHB->APB
//              read is checked (VG1/VG3/VG4).
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_006 — protocol category, wait_state_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_protocol_006 extends uvm_test;

  `uvm_component_utils(test_protocol_006)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_protocol_006", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the AHB->APB read is checked (VG1/VG3/VG4).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single NONSEQ read — multi-wait signal stability

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_protocol_006: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_protocol_006: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive one NONSEQ read, observe multi-wait signal stability ──
  task run_phase(uvm_phase phase);
    ahb_mst_test_protocol_006_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_protocol_006: starting");

    `uvm_info("PROTO006", "========== TEST_PROTOCOL_006 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the multi-wait read stimulus on AHB
    ahb_seq = ahb_mst_test_protocol_006_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transaction to propagate through the bridge.
    #200ns;

    `uvm_info("PROTO006", "========== TEST_PROTOCOL_006 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_protocol_006: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("PROTO006", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("PROTO006",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_protocol_006
