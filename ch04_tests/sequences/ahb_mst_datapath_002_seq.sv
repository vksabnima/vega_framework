// =============================================================================
// File        : ahb_mst_datapath_002_seq.sv
// Description : TEST_MAIN_DATAPATH_002 — Address forwarding
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_002
//   name     : address_forwarding
//   req_ref  : REQ_003 (Single Transfer Conversion)
//   objective: Verify AHB addresses are forwarded unchanged to APB
//
// Steps:
//   1. Write 0xCAFE_BABE to 0x0000_5A5A, read back and verify
//   2. Write 0x1234_5678 to 0x0000_A5A4 (word-aligned), read back and verify
//   3. Write 0x0000_0001 to 0x0000_0000 (min address), read back and verify
//   4. Write 0xBEEF_F00D to 0x0000_EEFC (near max, avoids 0x0F00 reg range),
//      read back and verify
//
// Pass criteria:
//   1. All write-readback comparisons match
//   2. Scoreboard VG1 confirms address forwarding on APB side
//
// Verification goals exercised: VG1, VG2, VG3, VG4, VG6
// =============================================================================

class ahb_mst_datapath_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_002_seq)

  function new(string name = "ahb_mst_datapath_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_002: Address forwarding =====", UVM_NONE)

    // Test 1: Mid-range address 0x5A5A
    write_and_verify("DATAPATH_002_addr1", 32'h0000_5A5A, 32'hCAFE_BABE);

    // Test 2: Word-aligned address 0xA5A4
    write_and_verify("DATAPATH_002_addr2", 32'h0000_A5A4, 32'h1234_5678);

    // Test 3: Minimum address 0x0000
    write_and_verify("DATAPATH_002_addr3", 32'h0000_0000, 32'h0000_0001);

    // Test 4: Near-max address 0xEEFC (avoids register range 0x0F00-0x0F0F)
    write_and_verify("DATAPATH_002_addr4", 32'h0000_EEFC, 32'hBEEF_F00D);

    print_summary("TEST_MAIN_DATAPATH_002");
  endtask

endclass
