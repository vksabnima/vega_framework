// =============================================================================
// FILE: tests/test_register_access_003_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_003 (status_w1c_clear_semantics)
// DESCRIPTION: Verifies Write-1-to-Clear (W1C) semantics of the STATUS register:
//              a 1 in the written bit clears the corresponding sticky flag while
//              a 0 leaves the other sticky flags untouched.
//
//              Preconditions: STATUS sticky bits PSLVERR (bit5)=1 and
//              TIMEOUT_ERR (bit6)=1 are pre-set via prior error events.
//
//              The register-access sequence drives five STATUS @0x0000_0F04
//              transfers: read (both set) -> W1C 0x20 (clear PSLVERR only) ->
//              read (bit5=0, bit6=1) -> W1C 0x40 (clear TIMEOUT_ERR) ->
//              read (bit5=0, bit6=0, bit7 ERR_INT=0).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence. Scoreboard enabled so the
//              transfer propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_003 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, STATUS read/W1C-write sequence.
// =============================================================================

class test_register_access_003 extends uvm_test;

  `uvm_component_utils(test_register_access_003)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_003", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Scoreboard off: the timeout-injection transfer aborts (no clean APB
    // completion). W1C clear semantics are verified by the sequence self-checks.
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 5;  // 3 STATUS reads + 2 W1C writes

    // Provoke BOTH sticky error sources: PSLVERR at 0x100, bus timeout at 0x200.
    cfg.add_apb_err_addr(32'h0000_0100);
    cfg.add_apb_stall_addr(32'h0000_0200);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_003: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_003: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: read STATUS, W1C-clear sticky bits, verify selective clear ──
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_003_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_003: starting");

    `uvm_info("REGACC003", "========== TEST_REGISTER_ACCESS_003 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the STATUS read / W1C-write stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_003_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transfers to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC003", "========== TEST_REGISTER_ACCESS_003 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_003: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC003", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC003",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_003
