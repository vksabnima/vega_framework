//----------------------------------------------------------------------
// File        : ahb_mst_error_009_seq.sv
// Description : TEST_ERROR_009 — error_interrupt_enable (ERPT-4)
//               Verify that ERR_INT (STATUS bit[7]) is only set when
//               ERR_INT_EN (CTRL bit[3]) is enabled.
//----------------------------------------------------------------------

class ahb_mst_error_009_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_009_seq)

  function new(string name = "ahb_mst_error_009_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_009: error_interrupt_enable =====", UVM_NONE)

    // ---- Step 1: Ensure ERR_INT_EN=0 — write CTRL=0x0071 (default) ----
    drive_reg_write(4'h0, 32'h0000_0071);

    // ---- Step 2: Generate address error ----
    drive_write_get_resp(32'h0010_0000, 32'hAAAA_1111, rdata, resp);
    check_resp("ADDR_ERR_NO_INT", resp, 1'b1);

    // ---- Step 3: Read STATUS — ADDR_ERR=1, ERR_INT=0 (ERR_INT_EN was off) ----
    drive_reg_read(4'h4, rdata);
    if (rdata[4] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "ADDR_ERR_SET FAIL: STATUS[4]=%0b expected 1", rdata[4]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "ADDR_ERR_SET PASS: STATUS[4]=%0b", rdata[4]), UVM_LOW)
    end

    if (rdata[7] !== 1'b0) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "ERR_INT_NOT_SET FAIL: STATUS[7]=%0b expected 0", rdata[7]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "ERR_INT_NOT_SET PASS: STATUS[7]=%0b", rdata[7]), UVM_LOW)
    end

    // ---- Step 4: Clear all error bits ----
    drive_reg_write(4'h4, 32'h0000_00F0);

    // ---- Step 5: Enable ERR_INT_EN — CTRL=0x0079 ----
    // bits: TIMEOUT_EN=1, TIMEOUT_VAL=111, ERR_INT_EN=1, ENABLE=1
    drive_reg_write(4'h0, 32'h0000_0079);

    // ---- Step 6: Generate address error again ----
    drive_write_get_resp(32'h0010_0000, 32'hBBBB_2222, rdata, resp);
    check_resp("ADDR_ERR_WITH_INT", resp, 1'b1);

    // ---- Step 7: Read STATUS — ADDR_ERR=1 AND ERR_INT=1 ----
    drive_reg_read(4'h4, rdata);
    if (rdata[4] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "ADDR_ERR_SET2 FAIL: STATUS[4]=%0b expected 1", rdata[4]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "ADDR_ERR_SET2 PASS: STATUS[4]=%0b", rdata[4]), UVM_LOW)
    end

    if (rdata[7] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "ERR_INT_SET FAIL: STATUS[7]=%0b expected 1", rdata[7]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "ERR_INT_SET PASS: STATUS[7]=%0b", rdata[7]), UVM_LOW)
    end

    // ---- Step 8: Clear ERR_INT only via W1C (bit[7]) ----
    drive_reg_write(4'h4, 32'h0000_0080);

    // ---- Step 9: Read STATUS — ERR_INT=0, ADDR_ERR still 1 ----
    drive_reg_read(4'h4, rdata);
    if (rdata[7] !== 1'b0) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "ERR_INT_CLEARED FAIL: STATUS[7]=%0b expected 0", rdata[7]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "ERR_INT_CLEARED PASS: STATUS[7]=%0b", rdata[7]), UVM_LOW)
    end

    if (rdata[4] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "ADDR_ERR_STILL FAIL: STATUS[4]=%0b expected 1", rdata[4]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "ADDR_ERR_STILL PASS: STATUS[4]=%0b", rdata[4]), UVM_LOW)
    end

    print_summary("TEST_ERROR_009");
  endtask
endclass
