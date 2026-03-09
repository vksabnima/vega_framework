// =============================================================================
// File        : ahb_mst_datapath_005_seq.sv
// Description : TEST_MAIN_DATAPATH_005 — INCR4 burst conversion
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_005
//   name     : incr4_burst_conversion
//   req_ref  : REQ_004 (Burst Transfer Handling)
//   objective: Verify 4-beat incrementing burst is forwarded to APB
//
// RTL NOTE: The bridge RTL does not implement burst-specific FSM logic
//   (burst_addr/burst_count/burst_active signals are declared but never
//   assigned). Each AHB beat is individually converted to an APB transfer
//   through IDLE->SETUP->ACCESS->IDLE. This test drives 4 sequential
//   single writes to simulate INCR4 burst behavior.
//
// Steps:
//   1. Write 0x1111_1111 to 0x1000
//   2. Write 0x2222_2222 to 0x1004
//   3. Write 0x3333_3333 to 0x1008
//   4. Write 0x4444_4444 to 0x100C
//   5. Read back all 4 addresses and verify
//
// Pass criteria:
//   1. All 4 write-readback comparisons match
//   2. Scoreboard confirms 4 individual APB transfers
//
// Verification goals exercised: VG1, VG2, VG3, VG6
// =============================================================================

class ahb_mst_datapath_005_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_005_seq)

  function new(string name = "ahb_mst_datapath_005_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_005: INCR4 burst conversion =====", UVM_NONE)

    // Drive 4 writes with HBURST=INCR4 (3'b011)
    drive_write_ex(32'h0000_1000, 32'h1111_1111, 3'b011);
    drive_write_ex(32'h0000_1004, 32'h2222_2222, 3'b011);
    drive_write_ex(32'h0000_1008, 32'h3333_3333, 3'b011);
    drive_write_ex(32'h0000_100C, 32'h4444_4444, 3'b011);

    // Read back all 4 and verify
    check_read("DATAPATH_005_beat0", 32'h0000_1000, 32'h1111_1111);
    check_read("DATAPATH_005_beat1", 32'h0000_1004, 32'h2222_2222);
    check_read("DATAPATH_005_beat2", 32'h0000_1008, 32'h3333_3333);
    check_read("DATAPATH_005_beat3", 32'h0000_100C, 32'h4444_4444);

    print_summary("TEST_MAIN_DATAPATH_005");
  endtask

endclass
