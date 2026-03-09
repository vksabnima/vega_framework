//----------------------------------------------------------------------
// File        : ahb_mst_reset_001_seq.sv
// Description : TEST_RESET_001 — soft_reset_initiation
//               Spec SRST-1 through SRST-6: Writing 1 to CTRL.SOFT_RST
//               initiates soft reset. SOFT_RST self-clears. STATUS error
//               bits and ERROR_ADDR/ERROR_INFO are cleared. CTRL register
//               preserved (except SOFT_RST bit).
//----------------------------------------------------------------------

class ahb_mst_reset_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_001_seq)

  function new(string name = "ahb_mst_reset_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_RESET_001: soft_reset_initiation =====", UVM_NONE)

    // ---- Step 1: Verify bridge works initially ----
    write_and_verify("RESET_001_PRE_WR", 32'h0000_1000, 32'hDEAD_BEEF);

    // ---- Step 2: Generate address error to set STATUS.ADDR_ERR ----
    drive_write_get_resp(32'h0001_0000, 32'hBAD0_ADD0, rdata, resp);
    check_resp("RESET_001_ADDR_ERR", resp, 1'b1);

    // ---- Step 3: Read STATUS, verify ADDR_ERR=1 (bit[4]) → 0x0000_0011 ----
    check_reg_read("RESET_001_STATUS_ERR", 4'h4, 32'h0000_0011);

    // ---- Step 4: Read ERROR_ADDR, verify captured ----
    check_reg_read("RESET_001_ERROR_ADDR", 4'h8, 32'h0001_0000);

    // ---- Step 5: Trigger soft reset — write CTRL with SOFT_RST=1 ----
    // CTRL = 0x0000_0073 (TIMEOUT_VAL=111, SOFT_RST=1, ENABLE=1)
    drive_reg_write(4'h0, 32'h0000_0073);

    // ---- Step 6: Read CTRL — SOFT_RST self-clears (SRST-5) → 0x0000_0071 ----
    check_reg_read("RESET_001_SOFT_RST_CLEAR", 4'h0, 32'h0000_0071);

    // ---- Step 7: Read STATUS — error bits cleared (SRST-3) → 0x0000_0001 ----
    check_reg_read("RESET_001_STATUS_CLEAR", 4'h4, 32'h0000_0001);

    // ---- Step 8: Read ERROR_ADDR — cleared by soft reset → 0x0000_0000 ----
    check_reg_read("RESET_001_ERROR_ADDR_CLR", 4'h8, 32'h0000_0000);

    // ---- Step 9: Verify bridge still works after soft reset ----
    write_and_verify("RESET_001_POST_WR", 32'h0000_2000, 32'hCAFE_BABE);

    print_summary("TEST_RESET_001");
  endtask
endclass
