//----------------------------------------------------------------------
// File        : ahb_mst_reg_access_006_seq.sv
// Description : TEST_REGISTER_ACCESS_006 — error_info_capture
//               Verify ERROR_INFO register captures error details per
//               Spec Table 9/10:
//                 [7:4] ERR_TYPE: 1=addr, 2=timeout, 3=PSLVERR
//                 [3]   ERR_WRITE: 1=write, 0=read
//                 [2:0] ERR_SIZE: transfer size
//----------------------------------------------------------------------

class ahb_mst_reg_access_006_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reg_access_006_seq)

  function new(string name = "ahb_mst_reg_access_006_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_REGISTER_ACCESS_006: error_info_capture =====", UVM_NONE)

    // Step 1: Read ERROR_INFO initially, expect 0x0000_0000
    check_reg_read("REG_ACCESS_006_INIT", 4'hC, 32'h0000_0000);

    // Step 2: Drive write to invalid address 0x0003_0000
    // ERR_TYPE=1(addr), ERR_WRITE=1, ERR_SIZE=010(word) → 0x0000_001A
    drive_write_get_resp(32'h0003_0000, 32'hBAAD_F00D, rdata, resp);

    // Step 3: Read ERROR_INFO, expect 0x0000_001A
    check_reg_read("REG_ACCESS_006_WRITE_ERR", 4'hC, 32'h0000_001A);

    // Step 4: Clear error via W1C to unlock error registers (ERPT-6)
    drive_reg_write(4'h4, 32'h0000_0010);

    // Step 5: Drive read from invalid address 0x0004_0000
    // ERR_TYPE=1(addr), ERR_WRITE=0, ERR_SIZE=010(word) → 0x0000_0012
    drive_read(32'h0004_0000, rdata, resp);

    // Step 5: Read ERROR_INFO, expect 0x0000_0012
    check_reg_read("REG_ACCESS_006_READ_ERR", 4'hC, 32'h0000_0012);

    print_summary("TEST_REGISTER_ACCESS_006");
  endtask
endclass
