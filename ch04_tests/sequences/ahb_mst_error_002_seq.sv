//----------------------------------------------------------------------
// File        : ahb_mst_error_002_seq.sv
// Description : TEST_ERROR_002 — address_error_no_apb
//               Verify that an address error does NOT generate an APB
//               transaction, and that normal APB transfers resume after
//               the error.  Scoreboard has skip_error_txns=1 in the test.
//----------------------------------------------------------------------

class ahb_mst_error_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_002_seq)

  function new(string name = "ahb_mst_error_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_002: address_error_no_apb =====", UVM_NONE)

    // ---- Step 1: Write to invalid address 0x0010_0000, expect HRESP=1 ----
    drive_write_get_resp(32'h0010_0000, 32'hBAD0_ADD0, rdata, resp);
    check_resp("INVALID_ADDR", resp, 1'b1);

    // ---- Step 2: Write to valid address 0x5000, expect HRESP=0 ----
    drive_write_get_resp(32'h0000_5000, 32'hBEEF_DEAD, rdata, resp);
    check_resp("VALID_WRITE", resp, 1'b0);

    // ---- Step 3: Read back 0x5000, expect 0xBEEF_DEAD ----
    check_read("VALID_READBACK", 32'h0000_5000, 32'hBEEF_DEAD);

    print_summary("TEST_ERROR_002");
  endtask
endclass
