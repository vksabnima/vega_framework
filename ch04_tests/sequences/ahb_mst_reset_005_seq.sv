//----------------------------------------------------------------------
// File        : ahb_mst_reset_005_seq.sv
// Description : TEST_RESET_005 — reset_recovery_timing
//               Post-reset only: After reset deasserts, wait 2 clock
//               cycles (#20), then write and verify to confirm bridge
//               recovers correctly.
//----------------------------------------------------------------------

class ahb_mst_reset_005_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reset_005_seq)

  function new(string name = "ahb_mst_reset_005_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_RESET_005: reset_recovery_timing =====", UVM_NONE)

    // ---- Step 1: Wait 2 clock cycles after reset deasserts ----
    `uvm_info(get_type_name(),
      "Step 1: Wait 2 clock cycles (#20) after reset deasserts", UVM_MEDIUM)
    #20;

    // ---- Step 2: Write 0x1234_ABCD to 0x1000, verify readback ----
    `uvm_info(get_type_name(),
      "Step 2: Write 0x1234_ABCD to 0x1000 and verify", UVM_MEDIUM)
    write_and_verify("RESET_005_RECOVERY_WR", 32'h0000_1000, 32'h1234_ABCD);

    print_summary("TEST_RESET_005");
  endtask
endclass
