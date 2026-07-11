// =============================================================================
// FILE: tests/test_register_access_006_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_006 (ctrl_reg_rw_field_writeback)
// DESCRIPTION: Verifies the R/W fields in the CTRL register accept programmed
//              values and read back correctly. A CTRL write of 0x0000_00A9
//              (ENABLE=1, TIMEOUT_VAL=3'b010, TIMEOUT_EN=1) is followed by a
//              CTRL read, which must return the same 0x0000_00A9.
//
//              Preconditions: PCLK/HCLK running, PRESETn deasserted, CTRL at
//              reset value 0x0000_0001 before the write.
//
//              The register-access sequence drives a CTRL write @0x0000_0F00
//              then a CTRL read @0x0000_0F00 and the scoreboard checks transfer
//              propagation HADDR->PADDR, HWDATA->PWDATA and HRDATA<-PRDATA.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the register-access sequence.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_006 — register_access category.
//
// CONFIDENCE: HIGH — standard test pattern, CTRL write then read-back.
// =============================================================================

class test_register_access_006 extends uvm_test;

  `uvm_component_utils(test_register_access_006)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_006", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the transfer propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 2;  // CTRL write then CTRL read-back

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_006: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_006: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: write CTRL then read it back ───────────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_006_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_006: starting");

    `uvm_info("REGACC006", "========== TEST_REGISTER_ACCESS_006 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the CTRL write-then-read stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_006_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transfers to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC006", "========== TEST_REGISTER_ACCESS_006 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_006: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC006", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC006",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_006
