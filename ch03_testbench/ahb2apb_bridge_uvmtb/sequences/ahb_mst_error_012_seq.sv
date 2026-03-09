//----------------------------------------------------------------------
// File        : ahb_mst_error_012_seq.sv
// Description : TEST_ERROR_012 — apb_deassert_after_timeout (TERR-4)
//               Verify timeout detection and bridge recovery.
//               Test class sets pready_delay=20 for the first phase,
//               then restores normal delay for recovery phase.
//----------------------------------------------------------------------

class ahb_mst_error_012_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_012_seq)

  function new(string name = "ahb_mst_error_012_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_012: apb_deassert_after_timeout =====", UVM_NONE)

    // ---- Step 1: Configure timeout — TIMEOUT_EN=1, VAL=0 (16 cycles), ENABLE=1 ----
    drive_reg_write(4'h0, 32'h0000_0081);

    // ---- Step 2: Write to 0x4000 — should timeout (pready_delay=20 > 16) ----
    drive_write_get_resp(32'h0000_4000, 32'hFEED_FACE, rdata, resp);
    check_resp("TIMEOUT_WRITE", resp, 1'b1);

    // ---- Step 3: Read STATUS — check TIMEOUT_ERR (bit[6]) ----
    drive_reg_read(4'h4, rdata);
    if (rdata[6] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "STATUS_TIMEOUT FAIL: STATUS[6]=%0b expected 1", rdata[6]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "STATUS_TIMEOUT PASS: STATUS[6]=%0b", rdata[6]), UVM_LOW)
    end

    // ---- Step 4: Read ERROR_ADDR, expect 0x4000 ----
    check_reg_read("ERROR_ADDR", 4'h8, 32'h0000_4000);

    // ---- Step 5: Clear TIMEOUT_ERR via W1C ----
    drive_reg_write(4'h4, 32'h0000_0040);

    // ---- Step 6: Recovery — test restores normal pready_delay ----
    // Restore default CTRL (timeout disabled for recovery): ENABLE=1
    drive_reg_write(4'h0, 32'h0000_0071);

    // Write and verify to confirm bridge recovered
    write_and_verify("RECOVERY_WV", 32'h0000_5000, 32'hABCD_1234);

    print_summary("TEST_ERROR_012");
  endtask
endclass
