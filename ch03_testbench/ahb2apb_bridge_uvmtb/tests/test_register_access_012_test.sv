// =============================================================================
// FILE: tests/test_register_access_012_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_012 (debug_regs_read_only_write_ignored)
// DESCRIPTION: Verifies that attempted APB writes to the captured debug registers
//              ERROR_ADDR (@0x0000_0F08) and ERROR_INFO (@0x0000_0F0C) have no
//              effect on the stored value — both are read-only (RO). The sequence
//              first induces a target error so ERROR_ADDR captures 0x0000_0100
//              (STATUS.PSLVERR=1), then attempts RO writes of 0xFFFF_FFFF and
//              0xAAAA_AAAA, then reads both registers back expecting the captured
//              values to be unchanged.
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              register-access sequence. Scoreboard enabled so the transaction
//              propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_012 — register_access category, captured debug
//     registers read-only / write-ignored verification.
//
// CONFIDENCE: HIGH — standard test pattern, capture then RO-write/read-back.
// =============================================================================

class test_register_access_012 extends uvm_test;

  `uvm_component_utils(test_register_access_012)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_012", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 5;  // capture write + 2 RO writes + 2 read-backs

    // Inject a PSLVERR target error on the capture address.
    cfg.add_apb_err_addr(32'h0000_0100);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_012: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_012: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive debug-register read-only / write-ignored stimulus ────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_012_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_012: starting");

    `uvm_info("REGACC012", "========== TEST_REGISTER_ACCESS_012 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the debug-register read-only / write-ignored stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_012_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC012", "========== TEST_REGISTER_ACCESS_012 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_012: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC012", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC012",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_012
