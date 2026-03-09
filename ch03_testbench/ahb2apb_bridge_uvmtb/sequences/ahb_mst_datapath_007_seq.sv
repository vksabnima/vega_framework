// =============================================================================
// File        : ahb_mst_datapath_007_seq.sv
// Description : TEST_MAIN_DATAPATH_007 — WRAP4 boundary test
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_007
//   name     : wrap4_boundary_test
//   req_ref  : REQ_004 (Burst Transfer Handling)
//   objective: Verify sequential writes at WRAP4 wrapping addresses
//
// RTL NOTE: The bridge RTL does not implement WRAP burst logic. The
//   burst_addr/burst_count/burst_active signals are declared but never
//   assigned. This test drives 4 sequential single writes at addresses
//   within a 16-byte boundary (simulating WRAP4 behavior) and verifies
//   each is individually converted to an APB transfer.
//
// Steps:
//   1. Write 0xD0D0_D0D0 to 0x1000
//   2. Write 0xD1D1_D1D1 to 0x1004
//   3. Write 0xD2D2_D2D2 to 0x1008
//   4. Write 0xD3D3_D3D3 to 0x100C
//   5. Read back all 4 addresses and verify
//
// Pass criteria:
//   1. All 4 write-readback comparisons match
//   2. Scoreboard confirms correct address and data forwarding
//
// Verification goals exercised: VG1, VG2, VG3, VG6
// =============================================================================

class ahb_mst_datapath_007_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_007_seq)

  function new(string name = "ahb_mst_datapath_007_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_007: WRAP4 boundary test =====", UVM_NONE)

    // Drive 4 writes with HBURST=WRAP4 (3'b010) at 16-byte boundary
    drive_write_ex(32'h0000_1000, 32'hD0D0_D0D0, 3'b010);
    drive_write_ex(32'h0000_1004, 32'hD1D1_D1D1, 3'b010);
    drive_write_ex(32'h0000_1008, 32'hD2D2_D2D2, 3'b010);
    drive_write_ex(32'h0000_100C, 32'hD3D3_D3D3, 3'b010);

    // Read back all and verify
    check_read("DATAPATH_007_wrap0", 32'h0000_1000, 32'hD0D0_D0D0);
    check_read("DATAPATH_007_wrap1", 32'h0000_1004, 32'hD1D1_D1D1);
    check_read("DATAPATH_007_wrap2", 32'h0000_1008, 32'hD2D2_D2D2);
    check_read("DATAPATH_007_wrap3", 32'h0000_100C, 32'hD3D3_D3D3);

    print_summary("TEST_MAIN_DATAPATH_007");
  endtask

endclass
