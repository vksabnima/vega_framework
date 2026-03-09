//----------------------------------------------------------------------
// File        : ahb_mst_reset_004_seq.sv
// Description : TEST_RESET_004 — reset_safe_state_timing
//               Pre-reset: Write to 0x1000 to get bridge active.
//               Post-reset: Verify bridge is operational by writing
//               and reading back from 0x2000.
//               Two sequence classes: pre-reset and post-reset.
//----------------------------------------------------------------------

// =========================================================================
// Pre-reset sequence — get bridge into active state
// =========================================================================
class ahb_mst_reset_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_004_seq)

  function new(string name = "ahb_mst_reset_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_RESET_004 PRE-RESET: reset_safe_state_timing =====", UVM_NONE)

    // ---- Step 1: Write to 0x1000 to get bridge active ----
    `uvm_info(get_type_name(),
      "Step 1: Write to 0x1000 to activate bridge (pre-reset)", UVM_MEDIUM)
    drive_write(32'h0000_1000, 32'hAAAA_BBBB);

    print_summary("TEST_RESET_004_PRE");
  endtask
endclass

// =========================================================================
// Post-reset sequence — verify bridge operational after reset
// =========================================================================
class ahb_mst_reset_004_post_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_004_post_seq)

  function new(string name = "ahb_mst_reset_004_post_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_RESET_004 POST-RESET: reset_safe_state_timing =====", UVM_NONE)

    // ---- Step 1: Write 0x5678_1234 to 0x2000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 1: Write 0x5678_1234 to 0x2000 and verify (post-reset)", UVM_MEDIUM)
    write_and_verify("RESET_004_POST_APB_WR", 32'h0000_2000, 32'h5678_1234);

    print_summary("TEST_RESET_004_POST");
  endtask
endclass
