//----------------------------------------------------------------------
// File        : ahb_mst_cross_feature_001_seq.sv
// Description : TEST_CROSS_FEATURE_001 — reset_during_burst_transfer
//               Simulated burst (sequential singles). Pre-reset writes
//               to 0x4000/0x4004. Post-reset reads them back (APB slave
//               memory survives reset in TB), then verifies bridge
//               recovery with a new write.
//               Two sequence classes: pre-reset and post-reset.
//----------------------------------------------------------------------

// =========================================================================
// Pre-reset sequence — simulated burst writes
// =========================================================================
class ahb_mst_cross_feature_001_pre_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_cross_feature_001_pre_seq)

  function new(string name = "ahb_mst_cross_feature_001_pre_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_CROSS_FEATURE_001 PRE-RESET: reset_during_burst_transfer =====", UVM_NONE)

    // ---- Step 1: Write 0x1111_1111 to 0x4000 ----
    `uvm_info(get_type_name(),
      "Step 1: Write 0x1111_1111 to 0x4000 (simulated burst beat 1)", UVM_MEDIUM)
    drive_write(32'h0000_4000, 32'h1111_1111);

    // ---- Step 2: Write 0x2222_2222 to 0x4004 ----
    `uvm_info(get_type_name(),
      "Step 2: Write 0x2222_2222 to 0x4004 (simulated burst beat 2)", UVM_MEDIUM)
    drive_write(32'h0000_4004, 32'h2222_2222);

    print_summary("TEST_CROSS_FEATURE_001_PRE");
  endtask
endclass

// =========================================================================
// Post-reset sequence — verify APB slave memory and bridge recovery
// =========================================================================
class ahb_mst_cross_feature_001_post_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_cross_feature_001_post_seq)

  function new(string name = "ahb_mst_cross_feature_001_post_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_CROSS_FEATURE_001 POST-RESET: reset_during_burst_transfer =====", UVM_NONE)

    // ---- Step 1: Read 0x4000, expect data survives in APB slave memory ----
    `uvm_info(get_type_name(),
      "Step 1: Read 0x4000 — APB slave memory survives reset (TB model)", UVM_MEDIUM)
    check_read("XFEAT_001_POST_RB1", 32'h0000_4000, 32'h1111_1111);

    // ---- Step 2: Read 0x4004, expect data survives in APB slave memory ----
    `uvm_info(get_type_name(),
      "Step 2: Read 0x4004 — APB slave memory survives reset (TB model)", UVM_MEDIUM)
    check_read("XFEAT_001_POST_RB2", 32'h0000_4004, 32'h2222_2222);

    // ---- Step 3: Write 0xDEAD_BEEF to 0x5000, verify (bridge recovered) ----
    `uvm_info(get_type_name(),
      "Step 3: Write 0xDEAD_BEEF to 0x5000 and verify (bridge recovery)", UVM_MEDIUM)
    write_and_verify("XFEAT_001_POST_RECOVERY", 32'h0000_5000, 32'hDEAD_BEEF);

    print_summary("TEST_CROSS_FEATURE_001_POST");
  endtask
endclass
