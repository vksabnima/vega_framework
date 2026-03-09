//----------------------------------------------------------------------
// File        : ahb_mst_datapath_011_seq.sv
// Description : TEST_MAIN_DATAPATH_011 — burst_1kb_boundary_no_cross (BURST-6)
//               Test that addresses near 1KB boundaries work correctly.
//               Writes to addresses within a 1KB page, at the boundary
//               edge, and into the next page.
//----------------------------------------------------------------------

class ahb_mst_datapath_011_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_011_seq)

  function new(string name = "ahb_mst_datapath_011_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_011: burst_1kb_boundary_no_cross =====", UVM_NONE)

    // ---- Step 1: Write to 4 addresses within first 1KB page ----
    `uvm_info(get_type_name(),
      "Step 1: Write to 0x03F0-0x03FC (within 1KB boundary)", UVM_MEDIUM)
    drive_write_ex(32'h0000_03F0, 32'hBD01_0001, 3'b011);  // INCR4
    drive_write_ex(32'h0000_03F4, 32'hBD01_0002, 3'b011);
    drive_write_ex(32'h0000_03F8, 32'hBD01_0003, 3'b011);
    drive_write_ex(32'h0000_03FC, 32'hBD01_0004, 3'b011);

    // ---- Step 2: Read back all 4, verify ----
    `uvm_info(get_type_name(),
      "Step 2: Read back all 4 addresses, verify data", UVM_MEDIUM)
    check_read("1KB_WITHIN_0", 32'h0000_03F0, 32'hBD01_0001);
    check_read("1KB_WITHIN_1", 32'h0000_03F4, 32'hBD01_0002);
    check_read("1KB_WITHIN_2", 32'h0000_03F8, 32'hBD01_0003);
    check_read("1KB_WITHIN_3", 32'h0000_03FC, 32'hBD01_0004);

    // ---- Step 3: Write to 0x0400 (next 1KB page), verify readback ----
    `uvm_info(get_type_name(),
      "Step 3: Write to 0x0400 (next 1KB page), verify readback", UVM_MEDIUM)
    write_and_verify("1KB_NEXT_PAGE", 32'h0000_0400, 32'hBD02_0001);

    // ---- Step 4: Write to 0x03FC (boundary edge), verify ----
    `uvm_info(get_type_name(),
      "Step 4: Write to 0x03FC (boundary edge), verify readback", UVM_MEDIUM)
    write_and_verify("1KB_BOUNDARY_EDGE", 32'h0000_03FC, 32'hBD03_0001);

    print_summary("TEST_MAIN_DATAPATH_011");
  endtask
endclass
