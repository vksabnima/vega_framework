//----------------------------------------------------------------------
// File        : ahb_mst_error_011_seq.sv
// Description : TEST_ERROR_011 — burst_terminated_on_protocol_error (PERR-7)
//               Verify PSLVERR error detection and capture.
//               The test class sets pslverr_inject=1 for the whole test.
//               Sequence writes once (gets PSLVERR), then verifies
//               ERROR_ADDR, ERROR_INFO, and STATUS capture.
//----------------------------------------------------------------------

class ahb_mst_error_011_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_011_seq)

  function new(string name = "ahb_mst_error_011_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_011: burst_terminated_on_protocol_error =====", UVM_NONE)

    // ---- Step 1: Write to 0x8000 with PSLVERR injected by test ----
    drive_write_get_resp(32'h0000_8000, 32'hDEAD_C0DE, rdata, resp);
    check_resp("PSLVERR_DETECTED", resp, 1'b1);

    // ---- Step 2: Read ERROR_ADDR — register reads don't go through APB ----
    check_reg_read("ERROR_ADDR", 4'h8, 32'h0000_8000);

    // ---- Step 3: Read ERROR_INFO — ERR_TYPE=3(pslverr), ERR_WRITE=1, ERR_SIZE=010 → 0x003A ----
    check_reg_read("ERROR_INFO", 4'hC, 32'h0000_003A);

    // ---- Step 4: Read STATUS — verify PSLVERR bit (bit[5]) is set ----
    drive_reg_read(4'h4, rdata);
    if (rdata[5] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "STATUS_PSLVERR FAIL: STATUS[5]=%0b expected 1", rdata[5]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "STATUS_PSLVERR PASS: STATUS[5]=%0b", rdata[5]), UVM_LOW)
    end

    print_summary("TEST_ERROR_011");
  endtask
endclass
