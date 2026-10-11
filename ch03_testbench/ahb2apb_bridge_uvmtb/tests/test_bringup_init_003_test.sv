// =============================================================================
// FILE: tests/test_bringup_init_003_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_BRINGUP_INIT_003 (single_domain_reset_then_immediate_reuse)
// DESCRIPTION: Verifies the bridge in single-clock-domain config (PCLK==HCLK)
//              returns to idle on reset and accepts a new transfer immediately
//              afterward. After reset deassert the bridge is in clean IDLE
//              (HREADY_OUT=1, STATUS=0x1); a new write to HADDR=0x0000_2000 is
//              driven on the very next cycle, then STATUS (0xF04) is read to
//              confirm the model is BUSY processing the reused transfer.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the bringup-init sequence.
//
// DERIVED FROM:
//   - XTP TEST_BRINGUP_INIT_003 — bringup_init category, parent feature
//     single_clock_domain_bringup (page 8).
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard disabled (bringup).
// =============================================================================

class test_bringup_init_003 extends uvm_test;

  `uvm_component_utils(test_bringup_init_003)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_bringup_init_003", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Bringup-style reset/reuse check — no scoreboard checking required.
    cfg.scoreboard_enable = 0;
    cfg.num_txns = 1;  // Single reuse transfer (+ a STATUS read) after reset

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_bringup_init_003: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_bringup_init_003: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive immediate-reuse transfer after reset ────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_bringup_init_003_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_bringup_init_003: starting");

    `uvm_info("INIT003", "========== TEST_BRINGUP_INIT_003 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the single-clock-domain reset-reuse stimulus on AHB
    ahb_seq = ahb_mst_test_bringup_init_003_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transfer to propagate through the bridge.
    #200ns;

    `uvm_info("INIT003", "========== TEST_BRINGUP_INIT_003 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_bringup_init_003: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("INIT003", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("INIT003",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_bringup_init_003
