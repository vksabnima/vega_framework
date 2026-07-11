// =============================================================================
// FILE: tests/test_error_015_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_ERROR_015 (address_error_class_capture_and_recovery)
// DESCRIPTION: Verifies the address-error class is distinct from a target PSLVERR
//              path. With CTRL programmed for ENABLE=1 (0x0000_0001), a good write
//              at valid 0x0000_1000 (PWDATA=0x0000_5555, PSLVERR=0) completes OKAY
//              (PSEL=1, PENABLE=1 active phase reached, HREADY_OUT=1, HRESP=0) with
//              a clean STATUS. An injected write at unsupported 0xDEAD_0000
//              (PWDATA=0x0000_1111) flags an invalid-address: HRESP=1 within the
//              error response window (T4..T6) with no valid PSEL/PENABLE target
//              access and HREADY_OUT=1 at window close. STATUS.ADDR_ERR b4 is set
//              sticky (STATUS=0x0000_0011, READY b0=1) with ERR_INT b7=0
//              (ERR_INT_EN=0), ERROR_ADDR=0xDEAD_0000, ERROR_INFO direction=write /
//              address-error class. W1C of bit 4 (STATUS=0x0000_0010) clears it
//              (STATUS=0x0000_0001); SOFT_RST (CTRL=0x0000_0003) clears the error
//              log preserving config (STATUS=0x0000_0001, ERROR_ADDR=0,
//              ERROR_INFO=0). After reconfigure (CTRL=0x0000_0001), a post-recovery
//              good read at valid 0x0000_1008 returns HRDATA=0x0BAD_F00D (HRESP=0)
//              with a clean STATUS=0x0000_0001, proving data integrity and recovery.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase
//              starts the address-error capture/recovery sequence. Scoreboard
//              enabled so address propagation and response checks run
//              automatically (VG1, VG2, VG3, VG4, VG5, VG6).
//
// DERIVED FROM:
//   - XTP TEST_ERROR_015 — error category, error_response_timing feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_error_015 extends uvm_test;

  `uvm_component_utils(test_error_015)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_error_015", uvm_component parent);
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
      `uvm_fatal("NOVIF", "test_error_015: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_error_015: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive the address-error capture / recovery flow ──────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_error_015_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_error_015: starting");

    `uvm_info("ERR015", "========== TEST_ERROR_015 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the address-error capture / recovery flow
    ahb_seq = ahb_mst_test_error_015_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow last transaction to propagate through the bridge.
    #200ns;

    `uvm_info("ERR015", "========== TEST_ERROR_015 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_error_015: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("ERR015", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("ERR015",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_error_015
