//----------------------------------------------------------------------
// File        : ahb_mst_reg_access_004_seq.sv
// Description : TEST_REGISTER_ACCESS_004 — status_ready_bit
//               Verify STATUS register reflects idle state correctly.
//               Spec Table 7: bit[0]=READY=1 when idle, bit[1]=BUSY=0.
//               Read STATUS before and after a normal transfer.
//----------------------------------------------------------------------

class ahb_mst_reg_access_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reg_access_004_seq)

  function new(string name = "ahb_mst_reg_access_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_REGISTER_ACCESS_004: status_ready_bit =====", UVM_NONE)

    // Step 1: Read STATUS when idle, expect READY=1 → 0x0000_0001
    check_reg_read("REG_ACCESS_004_IDLE_BEFORE", 4'h4, 32'h0000_0001);

    // Step 2: Perform a normal write/read to exercise the bridge
    write_and_verify("REG_ACCESS_004_TRANSFER", 32'h0000_3000, 32'hCAFE_BABE);

    // Step 3: Read STATUS after transfer completes, expect READY=1 → 0x0000_0001
    check_reg_read("REG_ACCESS_004_IDLE_AFTER", 4'h4, 32'h0000_0001);

    print_summary("TEST_REGISTER_ACCESS_004");
  endtask
endclass
