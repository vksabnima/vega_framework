// =============================================================================
// FILE: tests/test_register_access_002_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_002 (status_sticky_error_set_on_target_error)
// DESCRIPTION: Verifies PSLVERR and aggregated ERR_INT sticky bits in the STATUS
//              register are set and preserved after a target error event.
//              A source-side WRITE @0x0000_0200 provokes a target error
//              (PSLVERR injected on the APB side, HRESP=1 returned to source).
//              STATUS @0x0000_0F04 is then read twice without a W1C clear: both
//              reads must show PRDATA[5]=PSLVERR=1 and PRDATA[7]=ERR_INT=1,
//              proving the sticky bits are set and persist.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence. Scoreboard enabled so the
//              transfer propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_002 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, error write then two STATUS reads.
// =============================================================================

class test_register_access_002 extends uvm_test;

  `uvm_component_utils(test_register_access_002)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_002", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the transfer propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // one error write + two STATUS reads

    // Inject a target (PSLVERR) error at the source-side address this test
    // writes to provoke the sticky STATUS.PSLVERR / ERR_INT bits.
    cfg.add_apb_err_addr(32'h0000_0200);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_002: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_002: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: provoke target error, then read STATUS sticky bits twice ──
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_002_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_002: starting");

    `uvm_info("REGACC002", "========== TEST_REGISTER_ACCESS_002 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the error-write + STATUS-read stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_002_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transfers to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC002", "========== TEST_REGISTER_ACCESS_002 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_002: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC002", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC002",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_002
