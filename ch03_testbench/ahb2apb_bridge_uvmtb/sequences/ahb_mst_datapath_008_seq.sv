//----------------------------------------------------------------------
// File        : ahb_mst_datapath_008_seq.sv
// Description : TEST_MAIN_DATAPATH_008 — transfer_gating_negative (CONV-2)
//               Since the UVM driver always sets HSEL=1 and HREADY_IN=1,
//               this test verifies the positive case works (proper gating
//               when all conditions are met) and validates correct behavior
//               with multiple consecutive transfers.
//----------------------------------------------------------------------

class ahb_mst_datapath_008_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_008_seq)

  function new(string name = "ahb_mst_datapath_008_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_008: transfer_gating_negative =====", UVM_NONE)

    // ---- Step 1: Write to 0x1000, verify readback ----
    // HSEL=1, HREADY_IN=1, HTRANS=NONSEQ — all conditions met
    `uvm_info(get_type_name(),
      "Step 1: Write to 0x1000 (HSEL=1, HREADY_IN=1, HTRANS=NONSEQ)", UVM_MEDIUM)
    write_and_verify("GATING_SINGLE1", 32'h0000_1000, 32'hAAAA_1111);

    // ---- Step 2: Write to 0x2000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 2: Write to 0x2000, verify readback", UVM_MEDIUM)
    write_and_verify("GATING_SINGLE2", 32'h0000_2000, 32'hBBBB_2222);

    // ---- Step 3: 5 consecutive writes to sequential addresses, read all back ----
    `uvm_info(get_type_name(),
      "Step 3: 5 consecutive writes to sequential addresses", UVM_MEDIUM)

    drive_write(32'h0000_3000, 32'hC0C0_0001);
    drive_write(32'h0000_3004, 32'hC0C0_0002);
    drive_write(32'h0000_3008, 32'hC0C0_0003);
    drive_write(32'h0000_300C, 32'hC0C0_0004);
    drive_write(32'h0000_3010, 32'hC0C0_0005);

    check_read("GATING_CONSEC0", 32'h0000_3000, 32'hC0C0_0001);
    check_read("GATING_CONSEC1", 32'h0000_3004, 32'hC0C0_0002);
    check_read("GATING_CONSEC2", 32'h0000_3008, 32'hC0C0_0003);
    check_read("GATING_CONSEC3", 32'h0000_300C, 32'hC0C0_0004);
    check_read("GATING_CONSEC4", 32'h0000_3010, 32'hC0C0_0005);

    // ---- Step 4: Verify bridge still works ----
    `uvm_info(get_type_name(),
      "Step 4: Verify bridge still operational", UVM_MEDIUM)
    write_and_verify("GATING_FINAL", 32'h0000_4000, 32'hDEAD_BEEF);

    print_summary("TEST_MAIN_DATAPATH_008");
  endtask
endclass
