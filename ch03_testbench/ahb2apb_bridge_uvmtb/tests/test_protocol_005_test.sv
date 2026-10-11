// =============================================================================
// FILE: tests/test_protocol_005_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_PROTOCOL_005 (wait_state_basic_delayed_completion)
// DESCRIPTION: Verifies that a single target stall (PREADY=0) holds PENABLE
//              asserted and delays HREADY_OUT until PREADY=1. Drives one NONSEQ
//              write; the bridge progresses SETUP -> ACTIVE on the APB side.
//              While PREADY=0 the transfer is held (PSEL=1, PENABLE=1,
//              HREADY_OUT=0, PADDR/PWDATA unchanged). On PREADY=1 the transfer
//              completes: PSEL/PENABLE deassert, HREADY_OUT asserts, HRESP=0 and
//              STATUS.READY=1.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the protocol sequence. Scoreboard enabled so the AHB->APB
//              write is checked (VG1/VG2/VG4).
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_005 — protocol category, wait_state_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_protocol_005 extends uvm_test;

  `uvm_component_utils(test_protocol_005)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_protocol_005", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the AHB->APB write is checked (VG1/VG2/VG4).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // single NONSEQ write — basic wait-state completion

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_protocol_005: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_protocol_005: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive one NONSEQ write, observe wait-state delayed completion ─
  task run_phase(uvm_phase phase);
    ahb_mst_test_protocol_005_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_protocol_005: starting");

    `uvm_info("PROTO005", "========== TEST_PROTOCOL_005 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the basic wait-state stimulus on AHB
    ahb_seq = ahb_mst_test_protocol_005_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transaction to propagate through the bridge.
    #200ns;

    `uvm_info("PROTO005", "========== TEST_PROTOCOL_005 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_protocol_005: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("PROTO005", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("PROTO005",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_protocol_005
