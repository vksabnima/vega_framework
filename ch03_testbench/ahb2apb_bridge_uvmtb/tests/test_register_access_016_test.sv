// =============================================================================
// FILE: tests/test_register_access_016_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_016 (error_addr_error_info_readonly)
// DESCRIPTION: Verifies the read-only debug registers ERROR_ADDR (@0x0000_0F08)
//              and ERROR_INFO (@0x0000_0F0C): they reset to 0, capture the error
//              context on an ADDR_ERR event, and reject write attempts (RO). The
//              sequence reads both registers after reset (expect 0x0000_0000),
//              drives a write to an invalid address (0x0000_ABCD) to trigger
//              ADDR_ERR, reads ERROR_ADDR (expect 0x0000_ABCD) and ERROR_INFO
//              (expect non-zero context), attempts a write to RO ERROR_ADDR
//              (0xDEADBEEF), then re-reads to prove the value is unchanged.
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              register-access sequence. Scoreboard enabled so the transaction
//              propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_016 — register_access category, RO debug-register
//     reset value, error-context capture, and RO write-ignore verification.
//
// CONFIDENCE: HIGH — standard test pattern, reset read + error capture + RO
//             write-ignore read-back.
// =============================================================================

class test_register_access_016 extends uvm_test;

  `uvm_component_utils(test_register_access_016)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_016", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 7;  // 2 reset rds + invalid wr + 2 captured rds + RO wr + final rd

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_016: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_016: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive ERROR_ADDR/ERROR_INFO RO stimulus ────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_016_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_016: starting");

    `uvm_info("REGACC016", "========== TEST_REGISTER_ACCESS_016 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the ERROR_ADDR/ERROR_INFO RO stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_016_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC016", "========== TEST_REGISTER_ACCESS_016 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_016: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC016", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC016",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_016
