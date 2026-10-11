// =============================================================================
// FILE: tests/test_register_access_015_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_015 (status_register_reset_and_w1c)
// DESCRIPTION: Verifies the STATUS register (@0x0000_0F04) reset value and the
//              write-1-to-clear (W1C) semantics on its sticky error bits while
//              the read-only BUSY[1]/READY[0] bits remain unaffected. The
//              sequence reads STATUS after reset (expect 0x0000_0001), reads it
//              again after a target error sets the sticky bits (bit[7]/bit[5]),
//              W1C-clears bits 7 and 5 (write 0x0000_00A0), reads back to confirm
//              the cleared bits, then writes 0 and re-reads to prove writing 0 is
//              a no-op on sticky bits.
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              register-access sequence. Scoreboard enabled so the transaction
//              propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_015 — register_access category, STATUS reset value
//     and W1C sticky-bit clear verification.
//
// CONFIDENCE: HIGH — standard test pattern, reset read + W1C write + read-back.
// =============================================================================

class test_register_access_015 extends uvm_test;

  `uvm_component_utils(test_register_access_015)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_015", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 6;  // reset rd + err rd + W1C wr + rd-back + wr0 + re-read

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_015: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_015: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive STATUS reset / W1C stimulus ──────────────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_015_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_015: starting");

    `uvm_info("REGACC015", "========== TEST_REGISTER_ACCESS_015 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the STATUS reset / W1C stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_015_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC015", "========== TEST_REGISTER_ACCESS_015 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_015: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC015", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC015",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_015
