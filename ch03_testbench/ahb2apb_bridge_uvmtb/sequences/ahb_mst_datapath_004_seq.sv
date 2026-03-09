// =============================================================================
// File        : ahb_mst_datapath_004_seq.sv
// Description : TEST_MAIN_DATAPATH_004 — Read data forwarding
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_004
//   name     : read_data_forwarding
//   req_ref  : REQ_003 (Single Transfer Conversion)
//   objective: Verify read data returned from APB reaches AHB master unchanged
//
// Steps:
//   1. Write 0x9876_5432 to 0x3000, read back and verify
//   2. Write 0xFEDC_BA98 to 0x3004, read back and verify
//   3. Write 0x0F0F_0F0F to 0x3008, read back and verify
//
// Pass criteria:
//   1. All read-back values match the written data
//   2. Scoreboard VG3 confirms read data integrity
//
// Verification goals exercised: VG1, VG3, VG4, VG6
// =============================================================================

class ahb_mst_datapath_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_004_seq)

  function new(string name = "ahb_mst_datapath_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_004: Read data forwarding =====", UVM_NONE)

    // Write known patterns to three consecutive word-aligned addresses
    drive_write(32'h0000_3000, 32'h9876_5432);
    drive_write(32'h0000_3004, 32'hFEDC_BA98);
    drive_write(32'h0000_3008, 32'h0F0F_0F0F);

    // Read back each and verify — exercises VG3 (read data integrity)
    check_read("DATAPATH_004_rd1", 32'h0000_3000, 32'h9876_5432);
    check_read("DATAPATH_004_rd2", 32'h0000_3004, 32'hFEDC_BA98);
    check_read("DATAPATH_004_rd3", 32'h0000_3008, 32'h0F0F_0F0F);

    print_summary("TEST_MAIN_DATAPATH_004");
  endtask

endclass
