//----------------------------------------------------------------------
// File        : ahb_mst_error_007_seq.sv
// Description : TEST_ERROR_007 — pslverr_sampling_conditions
//               Verify PSLVERR is sampled only when PREADY=1.
//               The test class sets pslverr_inject=1 on the APB driver.
//               A write should produce HRESP=1.  After the test resets
//               pslverr_inject=0, a subsequent write should succeed and
//               data should be readable.
//----------------------------------------------------------------------

class ahb_mst_error_007_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_007_seq)

  function new(string name = "ahb_mst_error_007_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_007: pslverr_sampling_conditions =====", UVM_NONE)

    // ---- Step 1: Write to 0x7000 with PSLVERR injected ----
    drive_write_get_resp(32'h0000_7000, 32'hAAAA_BBBB, rdata, resp);
    check_resp("PSLVERR_DETECTED", resp, 1'b1);

    // ---- Step 2: Recovery — test resets pslverr_inject=0 before this point ----
    // Write to 0x7004 without PSLVERR (test has cleared pslverr_inject)
    drive_write_get_resp(32'h0000_7004, 32'hCCCC_DDDD, rdata, resp);
    check_resp("RECOVERY_WRITE", resp, 1'b0);

    // ---- Step 3: Read back 0x7004, expect 0xCCCC_DDDD ----
    check_read("RECOVERY_READBACK", 32'h0000_7004, 32'hCCCC_DDDD);

    print_summary("TEST_ERROR_007");
  endtask
endclass
