//----------------------------------------------------------------------
// File        : ahb_mst_datapath_010_seq.sv
// Description : TEST_MAIN_DATAPATH_010 — burst_early_termination (BURST-5)
//               The RTL treats each AHB transfer independently (no real
//               multi-beat burst FSM on APB side). This test verifies
//               sequential single transfers work correctly and the bridge
//               stays operational when a "burst" is terminated by a new
//               NONSEQ transaction.
//----------------------------------------------------------------------

class ahb_mst_datapath_010_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_010_seq)

  function new(string name = "ahb_mst_datapath_010_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_010: burst_early_termination =====", UVM_NONE)

    // ---- Step 1: Write 4 sequential addresses (simulating INCR4) ----
    `uvm_info(get_type_name(),
      "Step 1: Write 4 sequential addresses (0x5000-0x500C) simulating INCR4", UVM_MEDIUM)
    drive_write_ex(32'h0000_5000, 32'hB001_0001, 3'b011);  // INCR4
    drive_write_ex(32'h0000_5004, 32'hB001_0002, 3'b011);
    drive_write_ex(32'h0000_5008, 32'hB001_0003, 3'b011);
    drive_write_ex(32'h0000_500C, 32'hB001_0004, 3'b011);

    // ---- Step 2: Read back all 4, verify data ----
    `uvm_info(get_type_name(),
      "Step 2: Read back all 4 addresses, verify data integrity", UVM_MEDIUM)
    check_read("BURST_INCR4_0", 32'h0000_5000, 32'hB001_0001);
    check_read("BURST_INCR4_1", 32'h0000_5004, 32'hB001_0002);
    check_read("BURST_INCR4_2", 32'h0000_5008, 32'hB001_0003);
    check_read("BURST_INCR4_3", 32'h0000_500C, 32'hB001_0004);

    // ---- Step 3: Write 2 addresses, then write to new address (burst termination) ----
    `uvm_info(get_type_name(),
      "Step 3: Write 2 addresses then new NONSEQ (simulating burst termination)", UVM_MEDIUM)
    drive_write(32'h0000_6000, 32'hB002_0001);
    drive_write(32'h0000_6004, 32'hB002_0002);
    // Burst terminated by new NONSEQ to different address
    drive_write(32'h0000_7000, 32'hB003_0001);

    // ---- Step 4: Read back 0x7000, verify data ----
    `uvm_info(get_type_name(),
      "Step 4: Read back 0x7000 (new NONSEQ target), verify data", UVM_MEDIUM)
    check_read("BURST_TERM_NEW", 32'h0000_7000, 32'hB003_0001);

    // Also verify the earlier writes survived
    check_read("BURST_TERM_PRE0", 32'h0000_6000, 32'hB002_0001);
    check_read("BURST_TERM_PRE1", 32'h0000_6004, 32'hB002_0002);

    // ---- Step 5: Verify bridge still operational ----
    `uvm_info(get_type_name(),
      "Step 5: Verify bridge still operational after burst termination", UVM_MEDIUM)
    write_and_verify("BURST_RECOVERY", 32'h0000_8000, 32'hABCD_EF01);

    print_summary("TEST_MAIN_DATAPATH_010");
  endtask
endclass
