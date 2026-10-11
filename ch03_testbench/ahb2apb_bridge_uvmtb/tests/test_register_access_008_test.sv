// =============================================================================
// FILE: tests/test_register_access_008_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_008 (ctrl_reserved_bits_readonly_check)
// DESCRIPTION: Verifies that the CTRL reserved bits remain 0 and are not affected
//              by an attempted write of all-ones, while writable fields take the
//              written value (subject to SOFT_RST self-clear).
//
//              Preconditions: PCLK running, PRESETn deasserted, CTRL at reset
//              value 0x0000_0001.
//
//              The register-access sequence drives:
//                1. WRITE CTRL @0x0F00 = 0xFFFF_FFFF (attempt all-ones).
//                2. READ  CTRL @0x0F00 — expect bits31:8=0, bit2=0 (reserved
//                     RO=0); writable bits reflect the written ones.
//              The scoreboard checks transfer propagation HADDR->PADDR,
//              HWDATA->PWDATA and HRDATA<-PRDATA.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_008 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, CTRL all-ones write then read-back.
// =============================================================================

class test_register_access_008 extends uvm_test;

  `uvm_component_utils(test_register_access_008)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_008", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the transfer propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // CTRL write, CTRL read

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_008: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_008: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: CTRL all-ones write, CTRL read-back ─────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_008_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_008: starting");

    `uvm_info("REGACC008", "========== TEST_REGISTER_ACCESS_008 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the CTRL reserved-bits read-only stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_008_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transfers to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC008", "========== TEST_REGISTER_ACCESS_008 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_008: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC008", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC008",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_008
