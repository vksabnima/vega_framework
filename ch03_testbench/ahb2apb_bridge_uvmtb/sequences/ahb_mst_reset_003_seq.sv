//----------------------------------------------------------------------
// File        : ahb_mst_reset_003_seq.sv
// Description : TEST_RESET_003 — async_reset_assertion
//               Two sequence classes: pre-reset and post-reset.
//               The test class coordinates reset assertion between
//               the two phases via reset_ctrl_if.
//----------------------------------------------------------------------

// =========================================================================
// Pre-reset sequence — runs BEFORE reset is asserted
// =========================================================================
class ahb_mst_reset_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_003_seq)

  function new(string name = "ahb_mst_reset_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_RESET_003 PRE-RESET: async_reset_assertion =====", UVM_NONE)

    // ---- Step 1: Write 0x0000_008F to CTRL ----
    `uvm_info(get_type_name(),
      "Step 1: Write 0x0000_008F to CTRL (pre-reset)", UVM_MEDIUM)
    drive_reg_write(4'h0, 32'h0000_008F);

    // ---- Step 2: Write 0xDEAD_BEEF to 0x1000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 2: Write 0xDEAD_BEEF to 0x1000 and verify (pre-reset)", UVM_MEDIUM)
    write_and_verify("RESET_003_PRE_APB_WR", 32'h0000_1000, 32'hDEAD_BEEF);

    print_summary("TEST_RESET_003_PRE");
  endtask
endclass

// =========================================================================
// Post-reset sequence — runs AFTER reset deasserts
// =========================================================================
class ahb_mst_reset_003_post_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_003_post_seq)

  function new(string name = "ahb_mst_reset_003_post_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_RESET_003 POST-RESET: async_reset_assertion =====", UVM_NONE)

    // ---- Step 1: Read CTRL, check reset value 0x0000_0071 ----
    `uvm_info(get_type_name(),
      "Step 1: Read CTRL, verify reset value 0x0000_0071", UVM_MEDIUM)
    check_reg_read("RESET_003_POST_CTRL_RST", 4'h0, 32'h0000_0071);

    // ---- Step 2: Write 0xCAFE_BABE to 0x3000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 2: Write 0xCAFE_BABE to 0x3000 and verify (post-reset)", UVM_MEDIUM)
    write_and_verify("RESET_003_POST_APB_WR", 32'h0000_3000, 32'hCAFE_BABE);

    print_summary("TEST_RESET_003_POST");
  endtask
endclass
