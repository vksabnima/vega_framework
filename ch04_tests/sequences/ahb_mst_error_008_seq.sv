//----------------------------------------------------------------------
// File        : ahb_mst_error_008_seq.sv
// Description : TEST_ERROR_008 — error_recovery_back_to_back (ERCV-5)
//               Verify bridge accepts valid transfer immediately after
//               an error.  Generate address error, then immediately do
//               a valid write+readback, confirm STATUS.ADDR_ERR is set,
//               clear it via W1C, and do another write_and_verify.
//----------------------------------------------------------------------

class ahb_mst_error_008_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_008_seq)

  function new(string name = "ahb_mst_error_008_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_008: error_recovery_back_to_back =====", UVM_NONE)

    // ---- Step 1: Generate address error — write to 0x0010_0000 (>= 0x10000) ----
    drive_write_get_resp(32'h0010_0000, 32'hDEAD_BEEF, rdata, resp);
    check_resp("ADDR_ERR", resp, 1'b1);

    // ---- Step 2: Immediately write to valid address 0x1000 ----
    drive_write_get_resp(32'h0000_1000, 32'hBACE_2BAC, rdata, resp);
    check_resp("RECOVERY_WRITE", resp, 1'b0);

    // ---- Step 3: Read back 0x1000, verify data ----
    check_read("RECOVERY_READBACK", 32'h0000_1000, 32'hBACE_2BAC);

    // ---- Step 4: Read STATUS, verify ADDR_ERR (bit[4]) is set ----
    drive_reg_read(4'h4, rdata);
    if (rdata[4] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "STATUS_ADDR_ERR FAIL: STATUS[4]=%0b expected 1", rdata[4]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "STATUS_ADDR_ERR PASS: STATUS[4]=%0b", rdata[4]), UVM_LOW)
    end

    // ---- Step 5: Clear ADDR_ERR via W1C ----
    drive_reg_write(4'h4, 32'h0000_0010);

    // ---- Step 6: Another write_and_verify to 0x2000 ----
    write_and_verify("POST_CLEAR_WV", 32'h0000_2000, 32'hCAFE_BABE);

    print_summary("TEST_ERROR_008");
  endtask
endclass
