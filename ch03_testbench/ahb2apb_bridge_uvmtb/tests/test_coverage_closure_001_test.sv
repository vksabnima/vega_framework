// =============================================================================
// FILE: tests/test_coverage_closure_001_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_COVERAGE_CLOSURE_001
// DESCRIPTION: Directed coverage-closure test.  The feature regression leaves
//              the AHB_TXN group at 55.9% because the functional tests only ever
//              drive SINGLE/INCR4 bursts and WORD/HALFWORD sizes.  This test runs
//              one directed sequence that exercises every remaining HBURST
//              encoding (INCR, WRAP4/8/16, INCR8/16) as write+read, a BYTE-size
//              transfer, a read into the APB_HIGH window, and the MID_RANGE /
//              READ-direction decode-error cases — closing the open AHB_TXN and
//              ERROR_SCENARIOS bins to reach full functional closure.
//
//              Scoreboard ENABLED: forwardable transfers are checked for the
//              HADDR->PADDR / data mapping (VG1-VG4); out-of-range transfers are
//              expected to return HRESP=ERROR with no APB beat.
//
// DERIVED FROM:
//   - Coverage gap analysis (coverage_report_measured.txt) of the regression.
//
// CONFIDENCE: HIGH — directed single transfers, scoreboard enabled.
// =============================================================================

class test_coverage_closure_001 extends uvm_test;

  `uvm_component_utils(test_coverage_closure_001)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_coverage_closure_001", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // directed sequence drives its own fixed transfer list

    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_coverage_closure_001: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_coverage_closure_001: Failed to get apb_vif from config_db")

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    ahb_mst_test_coverage_closure_001_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_coverage_closure_001: starting");

    `uvm_info("COVCLOSE", "========== TEST_COVERAGE_CLOSURE_001 START ==========", UVM_NONE)

    // Reactive APB slave runs in the background [U3].
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    ahb_seq = ahb_mst_test_coverage_closure_001_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    #200ns;  // drain — let the final transfer propagate

    `uvm_info("COVCLOSE", "========== TEST_COVERAGE_CLOSURE_001 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_coverage_closure_001: done");
  endtask : run_phase

  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("COVCLOSE", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("COVCLOSE",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_coverage_closure_001
