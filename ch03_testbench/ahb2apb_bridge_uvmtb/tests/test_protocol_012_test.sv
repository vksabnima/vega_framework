// =============================================================================
// FILE: tests/test_protocol_012_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_PROTOCOL_012 (fsm_active_to_idle_completion)
// DESCRIPTION: Verifies that handshake completion (PREADY=1) returns the bridge
//              FSM to IDLE and deasserts PSEL/PENABLE. Drives a single accepted
//              NONSEQ write request (HSEL=1, HTRANS=New, HADDR=0x0000_1000) so the
//              bridge FSM enters ACTIVE (PSEL=1, PENABLE=1, PADDR=0x0000_1000).
//              When the APB target asserts PREADY=1 the handshake completes
//              (PRDATA=0x0000_ABCD captured) and the FSM must transition
//              ACTIVE->IDLE with PSEL=0, PENABLE=0. A follow-up STATUS register
//              read at 0xF04 confirms READY bit[0]=1 and BUSY bit[1]=0
//              (STATUS=0x0000_0001), proving the clean return to IDLE.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the protocol sequence. Scoreboard enabled so the AHB->APB
//              transfers are checked (VG1/VG3/VG4/VG6).
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_012 — protocol category, setup_active_state_machine
//     feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_protocol_012 extends uvm_test;

  `uvm_component_utils(test_protocol_012)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_protocol_012", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the AHB->APB transfers are checked (VG1/VG3/VG4/VG6).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // accepted NONSEQ write + STATUS read-back

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_protocol_012: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_protocol_012: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive accepted request, observe ACTIVE->IDLE completion ───────
  task run_phase(uvm_phase phase);
    ahb_mst_test_protocol_012_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_protocol_012: starting");

    `uvm_info("PROTO012", "========== TEST_PROTOCOL_012 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the request stimulus on AHB
    ahb_seq = ahb_mst_test_protocol_012_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("PROTO012", "========== TEST_PROTOCOL_012 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_protocol_012: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("PROTO012", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("PROTO012",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_protocol_012
