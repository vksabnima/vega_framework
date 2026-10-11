// =============================================================================
// FILE: tests/test_protocol_017_test.sv
// =============================================================================
// COMPONENT  : Test — TEST_PROTOCOL_017 (hresp_ok_stable_during_wait_states)
// DESCRIPTION: Verifies HRESP remains 0 (no premature/spurious error) throughout
//              target wait states and resolves to OK at completion when PREADY
//              finally asserts without error. Programs CTRL=0x0000_0001 (ENABLE
//              bit0, TIMEOUT_EN=0) then drives a single accepted NONSEQ read
//              request (HSEL=1, HTRANS=NONSEQ, HWRITE=0, HADDR=0x0000_4000) so the
//              bridge walks:
//                FLOW-1 capture (HRESP=0)
//                FLOW-2 target SETUP (PSEL=1, PENABLE=0, PADDR=0x0000_4000)
//                FLOW-4 target ACTIVE stall (PSEL=1, PENABLE=1, PREADY=0;
//                                            HREADY_OUT=0, HRESP=0 stable each cycle)
//                FLOW-5 source completion (PREADY=1, PSLVERR=0, PRDATA=0xCAFE_0001:
//                                          HREADY_OUT=1, HRESP=0, HRDATA=0xCAFE_0001)
//              Follow-up STATUS read at 0xF04 confirms STATUS=0x0000_0001 with no
//              sticky error bits set.
//
//              Mirrors the sanity_test structure: factory util, build_phase
//              gets the virtual interfaces and creates the env, run_phase starts
//              the protocol sequence. Scoreboard enabled so the AHB->APB transfers
//              are checked (VG1/VG3/VG4/VG6).
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_017 — protocol category, hresp_error_indication_output
//     feature.
//
// CONFIDENCE: HIGH — standard test pattern, scoreboard enabled.
// =============================================================================

class test_protocol_017 extends uvm_test;

  `uvm_component_utils(test_protocol_017)

  ahb2apb_bridge_env env;
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "test_protocol_017", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the DUT config object
    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");

    // Enable scoreboard so the AHB->APB transfers are checked (VG1/VG3/VG4/VG6).
    cfg.scoreboard_enable = 1;
    cfg.num_txns = 3;  // CTRL program + wait-state read + STATUS read

    // Get virtual interfaces from tb_top via config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", cfg.ahb_vif))
      `uvm_fatal("NOVIF", "test_protocol_017: Failed to get ahb_vif from config_db")
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", cfg.apb_vif))
      `uvm_fatal("NOVIF", "test_protocol_017: Failed to get apb_vif from config_db")

    // Publish config to all sub-components [U2] — null scope
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    // Build environment
    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction : build_phase

  // ── Run Phase: drive accepted read, observe HRESP=0 stable through wait states ──
  task run_phase(uvm_phase phase);
    ahb_mst_test_protocol_017_seq ahb_seq;
    apb_slv_bringup_seq apb_seq;

    phase.raise_objection(this, "test_protocol_017: starting");

    `uvm_info("PROTO017", "========== TEST_PROTOCOL_017 START ==========", UVM_NONE)

    // Start the reactive APB slave sequence in the background. Runs forever [U3]
    apb_seq = apb_slv_bringup_seq::type_id::create("apb_seq");
    fork
      apb_seq.start(env.apb_agt.sqr);
    join_none

    // Drive the request stimulus on AHB
    ahb_seq = ahb_mst_test_protocol_017_seq::type_id::create("ahb_seq");
    ahb_seq.start(env.ahb_agt.sqr);

    // Drain time — allow the transactions to propagate through the bridge.
    #200ns;

    `uvm_info("PROTO017", "========== TEST_PROTOCOL_017 COMPLETE ==========", UVM_NONE)

    phase.drop_objection(this, "test_protocol_017: done");
  endtask : run_phase

  // ── Report Phase ─────────────────────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);
    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) == 0 &&
        svr.get_severity_count(UVM_ERROR) == 0) begin
      `uvm_info("PROTO017", "\n\n***** TEST PASSED *****\n", UVM_NONE)
    end else begin
      `uvm_info("PROTO017",
        $sformatf("\n\n***** TEST FAILED ***** (FATAL=%0d ERROR=%0d)\n",
                  svr.get_severity_count(UVM_FATAL),
                  svr.get_severity_count(UVM_ERROR)), UVM_NONE)
    end
  endfunction : report_phase

endclass : test_protocol_017
