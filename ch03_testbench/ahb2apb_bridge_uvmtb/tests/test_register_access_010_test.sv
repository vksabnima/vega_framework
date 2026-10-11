// =============================================================================
// FILE: tests/test_register_access_010_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_010 (error_info_context_capture)
// DESCRIPTION: Verifies ERROR_INFO captures direction/beat/error-class context
//              for a target-side (PSLVERR) error. The sequence reads ERROR_INFO
//              @0x0000_0F0C (expect reset 0x0000_0000), issues a read to a valid
//              data address 0x0000_0100 that the APB slave answers with PSLVERR
//              (triggers STATUS.PSLVERR and HRESP=1), then re-reads ERROR_INFO
//              (expect non-zero with read-direction / target-error class).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence. Scoreboard enabled so the
//              transaction propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_010 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, ERROR_INFO context capture-and-read.
// =============================================================================

class test_register_access_010 extends uvm_test;

  `uvm_component_utils(test_register_access_010)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_010", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // ERROR_INFO read, target-error read, ERROR_INFO read

    // Inject a PSLVERR target error on the data-side read address.
    cfg.add_apb_err_addr(32'h0000_0100);

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_010: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_010: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive ERROR_INFO context-capture stimulus ─────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_010_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_010: starting");

    `uvm_info("REGACC010", "========== TEST_REGISTER_ACCESS_010 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the ERROR_INFO context-capture stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_010_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC010", "========== TEST_REGISTER_ACCESS_010 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_010: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC010", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC010",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_010
