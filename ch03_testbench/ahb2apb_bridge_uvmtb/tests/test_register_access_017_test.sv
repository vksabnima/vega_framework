// =============================================================================
// FILE: tests/test_register_access_017_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_REGISTER_ACCESS_017 (register_map_offset_decode)
// DESCRIPTION: Verifies each defined register offset decodes to the correct
//              register and that the 4-byte stride mapping is correct. The
//              sequence reads CTRL (@0x0000_0F00, expect 0x0000_0001), STATUS
//              (@0x0000_0F04, expect 0x0000_0001), ERROR_ADDR (@0x0000_0F08,
//              expect 0x0000_0000) and ERROR_INFO (@0x0000_0F0C, expect
//              0x0000_0000), then writes CTRL (0x0000_0080) and re-reads STATUS
//              to prove the write did not alias another register (offset
//              isolation).
//
//              Mirrors the sanity_test structure: factory util, build_phase gets
//              the virtual interfaces and creates the env, run_phase starts the
//              register-access sequence. Scoreboard enabled so the transaction
//              propagation HADDR->PADDR / HRDATA<-PRDATA is checked.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_017 — register_access category, per-offset decode
//     of the register map, 4-byte stride, and offset-isolation verification.
//
// CONFIDENCE: HIGH — standard test pattern, per-offset reset reads plus a
//             write/read offset-isolation check.
// =============================================================================

class test_register_access_017 extends uvm_test;

  `uvm_component_utils(test_register_access_017)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_register_access_017", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the register transaction propagation is checked.
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 6;  // 4 offset rds + CTRL wr + STATUS read-back

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_register_access_017: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_register_access_017: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive per-offset register decode stimulus ──────────────────
  task run_phase(uvm_phase phase);
    ahb_mst_test_register_access_017_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_register_access_017: starting");

    `uvm_info("REGACC017", "========== TEST_REGISTER_ACCESS_017 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the per-offset register decode stimulus on AHB
    ahb_seq = ahb_mst_test_register_access_017_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("REGACC017", "========== TEST_REGISTER_ACCESS_017 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_register_access_017: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("REGACC017", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("REGACC017",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_register_access_017
