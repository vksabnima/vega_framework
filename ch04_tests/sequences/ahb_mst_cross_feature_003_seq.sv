//----------------------------------------------------------------------
// File        : ahb_mst_cross_feature_003_seq.sv
// Description : TEST_CROSS_FEATURE_003 — soft_reset_during_address_error
//               Write to invalid address, verify error capture, trigger
//               soft reset via CTRL.SOFT_RST, verify error registers
//               cleared, then confirm bridge still operates normally.
//----------------------------------------------------------------------

class ahb_mst_cross_feature_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_cross_feature_003_seq)

  function new(string name = "ahb_mst_cross_feature_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_CROSS_FEATURE_003: soft_reset_during_address_error =====", UVM_NONE)

    // ---- Step 1: Write to invalid address 0x0010_0000, check HRESP=1 ----
    drive_write_get_resp(32'h0010_0000, 32'hBADA_DD00, rdata, resp);
    check_resp("XFEAT_003_INVALID_RESP", resp, 1'b1);

    // ---- Step 2: Read ERROR_ADDR, expect 0x0010_0000 ----
    check_reg_read("XFEAT_003_ERROR_ADDR", 4'h8, 32'h0010_0000);

    // ---- Step 3: Read ERROR_INFO ----
    // ERR_TYPE=1(addr), ERR_WRITE=1, ERR_SIZE=010 → 0x001A
    check_reg_read("XFEAT_003_ERROR_INFO", 4'hC, 32'h0000_001A);

    // ---- Step 4: Trigger soft reset — write CTRL with SOFT_RST=1 ----
    // 0x0000_0073 = TIMEOUT_VAL=111, SOFT_RST=1, ENABLE=1
    drive_reg_write(4'h0, 32'h0000_0073);

    // ---- Step 5: Read ERROR_ADDR — cleared by soft reset → 0x0000_0000 ----
    check_reg_read("XFEAT_003_ERROR_ADDR_POST", 4'h8, 32'h0000_0000);

    // ---- Step 6: Write 0x5555_AAAA to valid 0x6000, verify readback ----
    write_and_verify("XFEAT_003_RECOVERY", 32'h0000_6000, 32'h5555_AAAA);

    print_summary("TEST_CROSS_FEATURE_003");
  endtask
endclass
