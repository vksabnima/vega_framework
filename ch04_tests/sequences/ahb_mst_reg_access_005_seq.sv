//----------------------------------------------------------------------
// File        : ahb_mst_reg_access_005_seq.sv
// Description : TEST_REGISTER_ACCESS_005 — error_addr_capture
//               Verify ERROR_ADDR register captures the failing address
//               when an invalid (out-of-APB-range) address is driven.
//               Reset value is 0x0000_0000.
//----------------------------------------------------------------------

class ahb_mst_reg_access_005_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reg_access_005_seq)

  function new(string name = "ahb_mst_reg_access_005_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_REGISTER_ACCESS_005: error_addr_capture =====", UVM_NONE)

    // Step 1: Read ERROR_ADDR initially, expect 0x0000_0000
    `uvm_info(get_type_name(),
      "Step 1: Read ERROR_ADDR, verify initial value 0x0000_0000", UVM_MEDIUM)
    check_reg_read("REG_ACCESS_005_INIT", 4'h8, 32'h0000_0000);

    // Step 2: Drive write to invalid address 0x0001_FFFF (> 0xFFFF APB range)
    `uvm_info(get_type_name(),
      "Step 2: Write to invalid address 0x0001_FFFF (out of APB range)", UVM_MEDIUM)
    drive_write_get_resp(32'h0001_FFFF, 32'hDEAD_0001, rdata, resp);

    // Step 3: Read ERROR_ADDR, expect 0x0001_FFFF
    `uvm_info(get_type_name(),
      "Step 3: Read ERROR_ADDR, expect 0x0001_FFFF", UVM_MEDIUM)
    check_reg_read("REG_ACCESS_005_ERR1", 4'h8, 32'h0001_FFFF);

    // Step 4: Clear error via W1C to unlock error registers (ERPT-6)
    `uvm_info(get_type_name(),
      "Step 4: Clear ADDR_ERR via W1C to unlock error registers", UVM_MEDIUM)
    drive_reg_write(4'h4, 32'h0000_0010);

    // Step 5: Drive write to another invalid address 0x0002_AAAA
    `uvm_info(get_type_name(),
      "Step 5: Write to invalid address 0x0002_AAAA", UVM_MEDIUM)
    drive_write_get_resp(32'h0002_AAAA, 32'hDEAD_0002, rdata, resp);

    // Step 6: Read ERROR_ADDR, expect 0x0002_AAAA (updated after clear)
    `uvm_info(get_type_name(),
      "Step 6: Read ERROR_ADDR, expect 0x0002_AAAA", UVM_MEDIUM)
    check_reg_read("REG_ACCESS_005_ERR2", 4'h8, 32'h0002_AAAA);

    print_summary("TEST_REGISTER_ACCESS_005");
  endtask
endclass
