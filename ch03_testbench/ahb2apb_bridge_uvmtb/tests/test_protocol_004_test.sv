// =============================================================================
// FILE: tests/test_protocol_004_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_PROTOCOL_004 (read_data_returned_only_after_target_completion)
// DESCRIPTION: Verifies that on a read transfer HRDATA is not presented to the
//              source until target completion (PREADY=1) occurs in the ACTIVE
//              phase. Drives one NONSEQ read; the bridge progresses SETUP ->
//              ACTIVE on the APB side. While PREADY=0 the read is held
//              (HREADY_OUT=0, HRDATA not valid). On PREADY=1 the transfer
//              completes: PSEL/PENABLE deassert, HREADY_OUT asserts and the
//              captured PRDATA=0xDEAD_BEEF returns to the source as HRDATA,
//              HRESP=0.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the protocol sequence. Scoreboard enabled so the APB->AHB
//              read-data return is checked (VG3).
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_004 — protocol category, transfer_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_protocol_004 extends uvm_test;

  `uvm_component_utils(test_protocol_004)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_protocol_004", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the APB->AHB read-data return is checked (VG3).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single NONSEQ read — completion-gated read return

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_protocol_004: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_protocol_004: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive one NONSEQ read, observe completion-gated read return ──
  task run_phase(uvm_phase phase);
    ahb_mst_test_protocol_004_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_protocol_004: starting");

    `uvm_info("PROTO004", "========== TEST_PROTOCOL_004 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the completion-gated read return stimulus on AHB
    ahb_seq = ahb_mst_test_protocol_004_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transaction to propagate through the bridge.
    #200ns;

    `uvm_info("PROTO004", "========== TEST_PROTOCOL_004 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_protocol_004: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("PROTO004", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("PROTO004",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_protocol_004
