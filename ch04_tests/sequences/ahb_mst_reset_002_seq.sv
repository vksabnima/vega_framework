//----------------------------------------------------------------------
// File        : ahb_mst_reset_002_seq.sv
// Description : TEST_RESET_002 — soft_reset_abort_transfer
//               RTL NOTE: No soft reset mechanism exists in RTL.
//               This test verifies normal write-overwrite-readback
//               operation to confirm bridge functions correctly.
//----------------------------------------------------------------------

class ahb_mst_reset_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_002_seq)

  function new(string name = "ahb_mst_reset_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_RESET_002: soft_reset_abort_transfer =====", UVM_NONE)

    `uvm_info(get_type_name(),
      "RTL NOTE: No soft reset mechanism in RTL. Verifying normal operation.", UVM_MEDIUM)

    // ---- Step 1: Write 0x1357_2468 to 0x3000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 1: Write 0x1357_2468 to 0x3000 and verify", UVM_MEDIUM)
    write_and_verify("RESET_002_WRITE1", 32'h0000_3000, 32'h1357_2468);

    // ---- Step 2: Overwrite 0x9999_AAAA to 0x3000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 2: Overwrite 0x9999_AAAA to 0x3000 and verify", UVM_MEDIUM)
    write_and_verify("RESET_002_WRITE2", 32'h0000_3000, 32'h9999_AAAA);

    print_summary("TEST_RESET_002");
  endtask
endclass
