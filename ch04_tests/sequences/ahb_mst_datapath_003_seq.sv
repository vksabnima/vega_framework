// =============================================================================
// File        : ahb_mst_datapath_003_seq.sv
// Description : TEST_MAIN_DATAPATH_003 — Write data forwarding
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_003
//   name     : write_data_forwarding
//   req_ref  : REQ_003 (Single Transfer Conversion)
//   objective: Verify multiple data patterns written on AHB reach APB intact
//
// Steps:
//   1. Write 0x1234_ABCD to 0x2000, read back and verify
//   2. Write 0xFFFF_FFFF to 0x2000, read back and verify
//   3. Write 0x0000_0000 to 0x2000, read back and verify
//   4. Write 0xAAAA_5555 to 0x2000, read back and verify
//   5. Write 0x5555_AAAA to 0x2000, read back and verify
//
// Pass criteria:
//   1. All write-readback comparisons match
//   2. Scoreboard VG2 confirms write data integrity on APB side
//
// Verification goals exercised: VG2, VG3, VG4, VG6
// =============================================================================

class ahb_mst_datapath_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_003_seq)

  function new(string name = "ahb_mst_datapath_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_003: Write data forwarding =====", UVM_NONE)

    // Pattern 1: Mixed nibbles
    write_and_verify("DATAPATH_003_pat1", 32'h0000_2000, 32'h1234_ABCD);

    // Pattern 2: All ones
    write_and_verify("DATAPATH_003_pat2", 32'h0000_2000, 32'hFFFF_FFFF);

    // Pattern 3: All zeros
    write_and_verify("DATAPATH_003_pat3", 32'h0000_2000, 32'h0000_0000);

    // Pattern 4: Alternating bits (A/5)
    write_and_verify("DATAPATH_003_pat4", 32'h0000_2000, 32'hAAAA_5555);

    // Pattern 5: Alternating bits inverted (5/A)
    write_and_verify("DATAPATH_003_pat5", 32'h0000_2000, 32'h5555_AAAA);

    print_summary("TEST_MAIN_DATAPATH_003");
  endtask

endclass
