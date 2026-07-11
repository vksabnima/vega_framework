// =============================================================================
// FILE: tests/test_error_009_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_009 (target_error_basic_pslverr_capture)
// DESCRIPTION: Verifies a single target-side error (PSLVERR=1) during an active
//              access is detected, propagated to HRESP, captured in
//              ERROR_INFO/STATUS, and the model recovers cleanly with a clean
//              error log after recovery. With CTRL programmed for ENABLE=1
//              (0x0000_0001, TIMEOUT_EN=0), a good write at 0x0000_1000
//              (0xCAFE_0001) completes OKAY (HRESP=0, HREADY_OUT=1) with a clean
//              STATUS. An injected write at 0x0000_2000 (0xDEAD_0002) with
//              PSLVERR=1 at the target active phase fires the error: HRESP=1 and
//              STATUS sets PSLVERR b5=1 (sticky), the error log captures
//              ERROR_ADDR=0x0000_2000 and ERROR_INFO (direction=write,
//              class=target-error). The interrupt and sticky flags clear via W1C
//              (STATUS=0x0000_0080 then 0x0000_0020), SOFT_RST recovery
//              (CTRL=0x0000_0003) clears the error log and preserves config, and
//              a post-recovery good read at 0x0000_3000 proves data integrity
//              (HRDATA=0xBEEF_0003, HRESP=0) with a clean STATUS=0x0000_0001.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the pslverr-capture sequence. Scoreboard enabled so
//              address propagation and response checks run automatically
//              (VG1, VG2, VG3, VG4, VG5).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_009 — error category, target_error_scenario feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_009 extends uvm_test;

  `uvm_component_utils(test_error_009)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_009", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so address propagation / responses are checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 1;  // sequence drives its own fixed flow

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_error_009: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_009: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the target-side PSLVERR capture flow ───────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_009_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_009: starting");

    `uvm_info("ERR009", "========== TEST_ERROR_009 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the target-side PSLVERR capture flow
    ahb_seq = ahb_mst_test_error_009_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR009", "========== TEST_ERROR_009 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_009: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR009", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR009",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_009
