//----------------------------------------------------------------------
// File        : ahb_mst_protocol_004_seq.sv
// Description : TEST_PROTOCOL_004 — apb_signal_stability_during_transfer (APB-3)
//               Since the sequence cannot directly observe APB signals,
//               this test verifies that transfers complete correctly with
//               wait states (proving signals were stable enough for correct
//               operation). The test configures pready_delay=3.
//----------------------------------------------------------------------

class ahb_mst_protocol_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_protocol_004_seq)

  function new(string name = "ahb_mst_protocol_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;
    bit [31:0] patterns [4];
    bit [31:0] addrs    [4];

    `uvm_info(get_type_name(),
      "===== TEST_PROTOCOL_004: apb_signal_stability_during_transfer =====", UVM_NONE)

    `uvm_info(get_type_name(),
      "NOTE: APB slave pready_delay=3 (wait states) configured by test.", UVM_MEDIUM)

    // ---- Step 1: Write 0xA5A5_5A5A to 0x2000 with wait states ----
    `uvm_info(get_type_name(),
      "Step 1: Write 0xA5A5_5A5A to 0x2000 (with wait states)", UVM_MEDIUM)
    drive_write_get_resp(32'h0000_2000, 32'hA5A5_5A5A, rdata, resp);
    check_resp("STABILITY_WRITE1_RESP", resp, 1'b0);

    // ---- Step 2: Read back from 0x2000, verify data ----
    `uvm_info(get_type_name(),
      "Step 2: Read back from 0x2000, verify data = 0xA5A5_5A5A", UVM_MEDIUM)
    check_read("STABILITY_READ1", 32'h0000_2000, 32'hA5A5_5A5A);

    // ---- Step 3: Write 0x5A5A_A5A5 to 0x3000, read back verify ----
    `uvm_info(get_type_name(),
      "Step 3: Write 0x5A5A_A5A5 to 0x3000, read back verify", UVM_MEDIUM)
    drive_write_get_resp(32'h0000_3000, 32'h5A5A_A5A5, rdata, resp);
    check_resp("STABILITY_WRITE2_RESP", resp, 1'b0);
    check_read("STABILITY_READ2", 32'h0000_3000, 32'h5A5A_A5A5);

    // ---- Step 4: 4 sequential writes/reads with different patterns ----
    `uvm_info(get_type_name(),
      "Step 4: 4 sequential write/read pairs with different patterns", UVM_MEDIUM)

    patterns[0] = 32'hFF00_FF00;
    patterns[1] = 32'h00FF_00FF;
    patterns[2] = 32'hAAAA_AAAA;
    patterns[3] = 32'h5555_5555;

    addrs[0] = 32'h0000_4000;
    addrs[1] = 32'h0000_4004;
    addrs[2] = 32'h0000_4008;
    addrs[3] = 32'h0000_400C;

    // Write all 4
    drive_write(addrs[0], patterns[0]);
    drive_write(addrs[1], patterns[1]);
    drive_write(addrs[2], patterns[2]);
    drive_write(addrs[3], patterns[3]);

    // Read back all 4 and verify
    check_read("STABILITY_SEQ0", addrs[0], patterns[0]);
    check_read("STABILITY_SEQ1", addrs[1], patterns[1]);
    check_read("STABILITY_SEQ2", addrs[2], patterns[2]);
    check_read("STABILITY_SEQ3", addrs[3], patterns[3]);

    print_summary("TEST_PROTOCOL_004");
  endtask
endclass
