// =============================================================================
// FILE: tests/test_register_access_014_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_014 (ctrl_register_reset_and_rw)
// DESCRIPTION: Verifies the CTRL register (@0x0000_0F00) reset value and the
//              read/write behavior of its writable bits via the peripheral-side
//              register access path. The sequence reads CTRL after reset (expect
//              0x0000_0001), writes 0x0000_00FB to the writable bits, and reads
//              CTRL back (expect 0x0000_00FB with reserved bits [31:8]/bit[2]=0).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              register-access sequence. Scoreboard enabled so the transaction
//              propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_014 — register_access category, CTRL reset value
//     and writable-bit read/write verification.
//
// CONFIDENCE: HIGH — standard test pattern, reset read + write + read-back.
// =============================================================================

class test_register_access_014 extends uvm_test;

  `uvm_component_utils(test_register_access_014)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_014", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // reset read + write + read-back

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_014: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_014: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive CTRL reset / read-write stimulus ─────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_014_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_014: starting");

    `uvm_info("REGACC014", "========== TEST_REGISTER_ACCESS_014 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the CTRL reset / read-write stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_014_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC014", "========== TEST_REGISTER_ACCESS_014 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_014: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC014", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC014",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_014
