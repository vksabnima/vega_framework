// =============================================================================
// File        : ahb_mst_datapath_006_seq.sv
// Description : TEST_MAIN_DATAPATH_006 — INCR address increment
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_006
//   name     : incr_address_increment
//   req_ref  : REQ_004 (Burst Transfer Handling)
//   objective: Verify address incrementing by word size (4 bytes)
//
// RTL NOTE: The bridge RTL does not implement burst-specific FSM logic.
//   Each AHB beat is individually converted to an APB transfer. This test
//   drives 4 sequential single writes with addresses incrementing by 4 to
//   verify correct word-aligned address forwarding.
//
// Steps:
//   1. For i=0..3: write pattern (0xA000_0000 + i) to addr (0x2000 + i*4)
//   2. Read back all 4 addresses and verify
//
// Pass criteria:
//   1. All 4 readback values match written patterns
//   2. Scoreboard VG1 confirms each address forwarded correctly
//
// Verification goals exercised: VG1, VG2, VG3, VG6
// =============================================================================

class ahb_mst_datapath_006_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_006_seq)

  function new(string name = "ahb_mst_datapath_006_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_006: INCR address increment =====", UVM_NONE)

    // Write pattern[i] with HBURST=INCR (3'b001) to addr 0x2000 + i*4
    drive_write_ex(32'h0000_2000, 32'hA000_0000, 3'b001);
    drive_write_ex(32'h0000_2004, 32'hA000_0001, 3'b001);
    drive_write_ex(32'h0000_2008, 32'hA000_0002, 3'b001);
    drive_write_ex(32'h0000_200C, 32'hA000_0003, 3'b001);

    // Read back all 4 and verify address-data correspondence
    check_read("DATAPATH_006_inc0", 32'h0000_2000, 32'hA000_0000);
    check_read("DATAPATH_006_inc1", 32'h0000_2004, 32'hA000_0001);
    check_read("DATAPATH_006_inc2", 32'h0000_2008, 32'hA000_0002);
    check_read("DATAPATH_006_inc3", 32'h0000_200C, 32'hA000_0003);

    print_summary("TEST_MAIN_DATAPATH_006");
  endtask

endclass
