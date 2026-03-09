// =============================================================================
// File        : ahb2apb_bridge_connectivity_001_test.sv
// Description : Connectivity Test 001 — AHB Idle HREADY High
//
// Purpose:
//   Verify that when the AHB bus is idle (no transactions driven), the bridge
//   keeps HREADY_OUT asserted high. This confirms basic bridge connectivity
//   and correct idle-state behavior.
//
// Pass criteria:
//   - HREADY_OUT === 1'b1 for 5 consecutive clock cycles after reset
//   - No UVM_FATAL or UVM_ERROR
//
// Confidence: HIGH — simple connectivity check, no data movement.
// =============================================================================

class ahb2apb_bridge_connectivity_001_test extends uvm_test;
  `uvm_component_utils(ahb2apb_bridge_connectivity_001_test)

  ahb2apb_bridge_env          env;
  ahb2apb_bridge_dut_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: create config, build environment
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg = ahb2apb_bridge_dut_config::type_id::create("cfg");
    cfg.num_txns = 1;
    cfg.scoreboard_enable = 1;
    cfg.ahb_mst_is_active = UVM_ACTIVE;
    cfg.apb_slv_is_active = UVM_ACTIVE;

    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, "*", "cfg", cfg);

    env = ahb2apb_bridge_env::type_id::create("env", this);
  endfunction

  // =========================================================================
  // end_of_elaboration_phase: disable scoreboard (no transactions to check)
  // =========================================================================
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    env.scb.enable = 0;
  endfunction

  // =========================================================================
  // run_phase: check HREADY_OUT=1 for 5 cycles after reset
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_connectivity_001_seq seq;
    virtual ahb_mst_if ahb_vif;
    int fail_count;

    phase.raise_objection(this, "CONN_001: starting");

    `uvm_info("CONN_001", "=== TEST START ===", UVM_NONE)

    // Wait for reset deassertion
    #150;

    // Get AHB master virtual interface from config_db
    if (!uvm_config_db#(virtual ahb_mst_if)::get(null, "uvm_test_top.env.ahb_agt.drv", "vif", ahb_vif))
      `uvm_fatal("CONN_001", "Failed to get ahb_mst vif from config_db")

    // Check HREADY_OUT === 1'b1 for 5 consecutive cycles
    fail_count = 0;
    repeat (5) begin
      @(ahb_vif.mon_cb);
      if (ahb_vif.mon_cb.HREADY_OUT !== 1'b1) begin
        `uvm_error("CONN_001", $sformatf("HREADY_OUT not high during idle: got %0b", ahb_vif.mon_cb.HREADY_OUT))
        fail_count++;
      end else begin
        `uvm_info("CONN_001", "HREADY_OUT=1 (OK)", UVM_HIGH)
      end
    end

    if (fail_count == 0)
      `uvm_info("CONN_001", "All 5 HREADY_OUT checks passed", UVM_LOW)

    // Start sequence (drives no transactions, just completes)
    seq = ahb_mst_connectivity_001_seq::type_id::create("seq");
    seq.start(env.ahb_agt.sqr);

    #(cfg.drain_time_ns);

    `uvm_info("CONN_001", "=== TEST COMPLETE ===", UVM_NONE)

    phase.drop_objection(this, "CONN_001: done");
  endtask

  // =========================================================================
  // report_phase: print TEST PASSED/FAILED based on UVM error count
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) == 0)
      `uvm_info("CONN_001", "========== TEST PASSED ==========", UVM_NONE)
    else
      `uvm_info("CONN_001", "========== TEST FAILED ==========", UVM_NONE)
  endfunction

endclass
