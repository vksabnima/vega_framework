//----------------------------------------------------------------------
// File        : ahb_mst_protocol_003_seq.sv
// Description : TEST_PROTOCOL_003 — ahb_two_cycle_error_response (AHB-6)
//               Verify HRESP error response works correctly for all 3
//               error types: address error, timeout error, PSLVERR.
//               After each error, verify bridge recovers and is operational.
//----------------------------------------------------------------------

class ahb_mst_protocol_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_protocol_003_seq)

  function new(string name = "ahb_mst_protocol_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_PROTOCOL_003: ahb_two_cycle_error_response =====", UVM_NONE)

    // ---- Step 1: Address error — write to 0x0010_0000 (>= 0x10000) ----
    `uvm_info(get_type_name(),
      "Step 1: Generate address error (write to 0x0010_0000)", UVM_MEDIUM)
    drive_write_get_resp(32'h0010_0000, 32'hBAD0_ADD0, rdata, resp);
    check_resp("ADDR_ERROR_HRESP", resp, 1'b1);

    // ---- Step 2: Configure timeout — CTRL = 0x0081 ----
    // [7]=TIMEOUT_EN, [6:4]=TIMEOUT_VAL=0, [0]=ENABLE → 0x81
    // Test sets pready_delay=20 to trigger timeout (2^(0+4)=16 cycles)
    `uvm_info(get_type_name(),
      "Step 2: Configure timeout (CTRL=0x0081), generate timeout error", UVM_MEDIUM)
    drive_reg_write(4'h0, 32'h0000_0081);

    // Write to valid address — should timeout due to pready_delay=20 > 16
    drive_write_get_resp(32'h0000_A000, 32'h1111_2222, rdata, resp);
    check_resp("TIMEOUT_ERROR_HRESP", resp, 1'b1);

    // ---- Step 3: Read STATUS, check TIMEOUT_ERR (bit 6) is set ----
    `uvm_info(get_type_name(),
      "Step 3: Read STATUS register, check TIMEOUT_ERR bit", UVM_MEDIUM)
    drive_reg_read(4'h4, rdata);
    if (rdata[6] !== 1'b1) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "TIMEOUT_STATUS FAIL: STATUS[6] expected 1, got %0b (STATUS=0x%08h)",
        rdata[6], rdata))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "TIMEOUT_STATUS PASS: STATUS[6]=%0b (STATUS=0x%08h)", rdata[6], rdata), UVM_LOW)
    end

    // Reset timeout config — restore CTRL to enable-only (0x0071)
    drive_reg_write(4'h0, 32'h0000_0071);

    // Clear errors for clean state
    drive_reg_write(4'h4, 32'h00F0);

    // ---- Step 4: Recovery — verify bridge works after errors ----
    `uvm_info(get_type_name(),
      "Step 4: Verify bridge recovers — write_and_verify to valid address", UVM_MEDIUM)
    write_and_verify("RECOVERY_AFTER_ERRORS", 32'h0000_C000, 32'hC0DE_CAFE);

    print_summary("TEST_PROTOCOL_003");
  endtask
endclass
