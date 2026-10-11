// =============================================================================
// FILE: tests/ahb2apb_bridge_sanity_test.sv
// =============================================================================
// COMPONENT  : Sanity Test
// DESCRIPTION: Drives num_txns (5) transactions with full scoreboard checking.
//              Verifies all verification goals VG1-VG6.
//              Pass if all goals pass and "TEST PASSED" is printed.
//              Purpose: If bringup passes but sanity fails, DUT behavior is wrong.
//
// DERIVED FROM:
//   - Manifest: num_txns=5, drain_time=200ns, all 6 VGs.
//   - Intent: Full CHECK section — all VG1-VG6 verified.
//
// CONFIDENCE: HIGH — standard test pattern with scoreboard enabled.
// =============================================================================

class ahb2apb_bridge_sanity_test extends uvm_test;

  `uvm_component_utils(ahb2apb_bridge_sanity_test)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "ahb2apb_bridge_sanity_test", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard for full checking
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 5;  // Manifest: stimulus.num_txns = 5

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "sanity_test: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "sanity_test: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: Drive num_txns transactions with scoreboard ───────────────
  task run_phase(uvm_phase phase);
    ahb_mst_bringup_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    // Raise objection — only in test [U6]
    phase.raise_objection(this, "sanity_test: starting");

    `uvm_info("SANITY", "========== SANITY TEST START ==========", UVM_NONE)
    `uvm_info("SANITY", $sformatf("Driving %0d transactions with full scoreboard", cfg.num_txns), UVM_NONE)

    // Start the reactive APB slave sequence in the background
    // Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive num_txns transactions on AHB
    ahb_seq = ahb_mst_bringup_seq::type_id::create("ahb_seq");
    ahb_seq.num_txns = cfg.num_txns;
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through bridge
    // and be captured by both monitors before test ends
    // Manifest: drain_time_ns = 200
    #200ns;

    `uvm_info("SANITY", "========== SANITY TEST COMPLETE ==========", UVM_NONE)

    // Drop objection [U6]
    phase.drop_objection(this, "sanity_test: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    // Manifest pass_criteria: max_uvm_errors=0, max_uvm_fatals=0
    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("SANITY", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("SANITY",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : ahb2apb_bridge_sanity_test