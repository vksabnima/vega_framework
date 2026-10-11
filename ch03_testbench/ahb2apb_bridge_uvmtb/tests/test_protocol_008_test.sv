// =============================================================================
// FILE: tests/test_protocol_008_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_PROTOCOL_008 (wait_state_back_to_back_after_stall)
// DESCRIPTION: Verifies that the bridge correctly releases back-pressure after a
//              stalled transfer and accepts a new transfer with proper
//              PSEL/PENABLE sequencing. Drives two NONSEQ writes back-to-back:
//              #1 HADDR=0x0000_4000/HWDATA=0x1111_2222 (stalled by PREADY=0 then
//              completed by PREADY=1), then #2 HADDR=0x0000_4004/HWDATA=0x3333_4444
//              accepted only after #1 completes. Expected: first transfer holds
//              HREADY_OUT=0 during the stall and =1 at completion; the second
//              transfer enters SETUP (PSEL=1, PENABLE=0) then ACTIVE (PSEL=1,
//              PENABLE=1), completing with HREADY_OUT=1, HRESP=0; bus returns to
//              idle (PSEL=0, PENABLE=0) with STATUS.READY=1, BUSY=0.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the protocol sequence. Scoreboard enabled so the AHB->APB
//              writes are checked (VG1/VG2/VG4/VG6).
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_008 — protocol category, wait_state_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_protocol_008 extends uvm_test;

  `uvm_component_utils(test_protocol_008)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_protocol_008", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the AHB->APB writes are checked (VG1/VG2/VG4/VG6).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // two NONSEQ writes — back-to-back-after-stall

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_protocol_008: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_protocol_008: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive two NONSEQ writes, observe back-to-back-after-stall ────
  task run_phase(uvm_phase phase);
    ahb_mst_test_protocol_008_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_protocol_008: starting");

    `uvm_info("PROTO008", "========== TEST_PROTOCOL_008 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the write stimulus on AHB
    ahb_seq = ahb_mst_test_protocol_008_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("PROTO008", "========== TEST_PROTOCOL_008 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_protocol_008: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("PROTO008", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("PROTO008",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_protocol_008
