// =============================================================================
// FILE: tests/test_register_access_009_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_009 (error_addr_capture_on_addr_error)
// DESCRIPTION: Verifies ERROR_ADDR captures the source-side address of an
//              address-error transaction. The sequence reads ERROR_ADDR
//              @0x0000_0F08 (expect reset 0x0000_0000), issues a write to the
//              invalid address 0xDEAD_BEEF (triggers STATUS.ADDR_ERR and an
//              error response), then re-reads ERROR_ADDR (expect 0xDEAD_BEEF).
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence. Scoreboard enabled so the
//              transaction propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_009 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, ERROR_ADDR capture-and-read.
// =============================================================================

class test_register_access_009 extends uvm_test;

  `uvm_component_utils(test_register_access_009)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_009", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // ERROR_ADDR read, invalid write, ERROR_ADDR read

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_009: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_009: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive ERROR_ADDR capture stimulus ─────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_009_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_009: starting");

    `uvm_info("REGACC009", "========== TEST_REGISTER_ACCESS_009 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the ERROR_ADDR capture stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_009_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC009", "========== TEST_REGISTER_ACCESS_009 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_009: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC009", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC009",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_009
