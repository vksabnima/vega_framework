//----------------------------------------------------------------------
// File        : ahb_mst_datapath_009_seq.sv
// Description : TEST_MAIN_DATAPATH_009 — direction_forwarding (CONV-6)
//               Verify that write and read directions are correctly
//               forwarded through the bridge. Alternates write/read
//               pairs to multiple addresses and verifies all data.
//----------------------------------------------------------------------

class ahb_mst_datapath_009_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_009_seq)

  function new(string name = "ahb_mst_datapath_009_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_009: direction_forwarding =====", UVM_NONE)

    // ---- Step 1: Write 0xDEAD_BEEF to 0x4000 ----
    `uvm_info(get_type_name(),
      "Step 1: Write 0xDEAD_BEEF to 0x4000", UVM_MEDIUM)
    drive_write(32'h0000_4000, 32'hDEAD_BEEF);

    // ---- Step 2: Read from 0x4000, verify 0xDEAD_BEEF ----
    `uvm_info(get_type_name(),
      "Step 2: Read from 0x4000, verify data (proves read direction works)", UVM_MEDIUM)
    check_read("DIR_FWD_READ1", 32'h0000_4000, 32'hDEAD_BEEF);

    // ---- Step 3: Write 0xCAFE_BABE to 0x4004 ----
    `uvm_info(get_type_name(),
      "Step 3: Write 0xCAFE_BABE to 0x4004", UVM_MEDIUM)
    drive_write(32'h0000_4004, 32'hCAFE_BABE);

    // ---- Step 4: Read from 0x4004, verify ----
    `uvm_info(get_type_name(),
      "Step 4: Read from 0x4004, verify data", UVM_MEDIUM)
    check_read("DIR_FWD_READ2", 32'h0000_4004, 32'hCAFE_BABE);

    // ---- Step 5: Alternate 5 write/read pairs to different addresses ----
    `uvm_info(get_type_name(),
      "Step 5: 5 alternating write/read pairs to verify direction forwarding", UVM_MEDIUM)

    drive_write(32'h0000_5000, 32'hA1B2_C3D4);
    check_read("DIR_FWD_ALT0", 32'h0000_5000, 32'hA1B2_C3D4);

    drive_write(32'h0000_5004, 32'hE5F6_0718);
    check_read("DIR_FWD_ALT1", 32'h0000_5004, 32'hE5F6_0718);

    drive_write(32'h0000_5008, 32'h1234_5678);
    check_read("DIR_FWD_ALT2", 32'h0000_5008, 32'h1234_5678);

    drive_write(32'h0000_500C, 32'h9ABC_DEF0);
    check_read("DIR_FWD_ALT3", 32'h0000_500C, 32'h9ABC_DEF0);

    drive_write(32'h0000_5010, 32'hFEDC_BA98);
    check_read("DIR_FWD_ALT4", 32'h0000_5010, 32'hFEDC_BA98);

    print_summary("TEST_MAIN_DATAPATH_009");
  endtask
endclass
