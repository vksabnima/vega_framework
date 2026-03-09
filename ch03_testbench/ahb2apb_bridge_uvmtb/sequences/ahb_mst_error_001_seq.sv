//----------------------------------------------------------------------
// File        : ahb_mst_error_001_seq.sv
// Description : TEST_ERROR_001 — address_error_detection
//               Verify the bridge detects an address error when addr > 0xFFFF
//               and is not in the register range.  Confirms HRESP=1,
//               ERROR_ADDR and ERROR_INFO capture, and post-error recovery.
//----------------------------------------------------------------------

class ahb_mst_error_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_001_seq)

  function new(string name = "ahb_mst_error_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_001: address_error_detection =====", UVM_NONE)

    // ---- Step 1: Write to valid address, expect HRESP=0 ----
    drive_write_get_resp(32'h0000_8000, 32'h1234_5678, rdata, resp);
    check_resp("VALID_WRITE", resp, 1'b0);

    // ---- Step 2: Read STATUS register (offset 0x4), log value ----
    drive_reg_read(4'h4, rdata);
    `uvm_info(get_type_name(), $sformatf("STATUS register = 0x%08h", rdata), UVM_LOW)

    // ---- Step 3: Write to invalid address 0x0001_0000, expect HRESP=1 ----
    drive_write_get_resp(32'h0001_0000, 32'hDEAD_BEEF, rdata, resp);
    check_resp("INVALID_ADDR_WRITE", resp, 1'b1);

    // ---- Step 4: Read ERROR_ADDR (offset 0x8), expect 0x0001_0000 ----
    check_reg_read("ERROR_ADDR", 4'h8, 32'h0001_0000);

    // ---- Step 5: Read ERROR_INFO (offset 0xC) ----
    // Spec Table 9/10: ERR_TYPE=1(addr), ERR_WRITE=1, ERR_SIZE=010 → 0x001A
    check_reg_read("ERROR_INFO", 4'hC, 32'h0000_001A);

    // ---- Step 6: Recovery — write to valid address, expect HRESP=0 ----
    drive_write_get_resp(32'h0000_7000, 32'hCAFE_BABE, rdata, resp);
    check_resp("RECOVERY_WRITE", resp, 1'b0);

    // ---- Step 7: Read back 0x7000, expect 0xCAFE_BABE ----
    check_read("RECOVERY_READBACK", 32'h0000_7000, 32'hCAFE_BABE);

    print_summary("TEST_ERROR_001");
  endtask
endclass
