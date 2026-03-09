//----------------------------------------------------------------------
// File        : ahb_mst_reg_access_001_seq.sv
// Description : TEST_REGISTER_ACCESS_001 — ctrl_register_access
//               Verify CTRL register reset value and read/write access.
//               Spec Table 6: reset value = 0x0000_0071
//               (TIMEOUT_VAL=3'b111, ENABLE=1)
//----------------------------------------------------------------------

class ahb_mst_reg_access_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reg_access_001_seq)

  function new(string name = "ahb_mst_reg_access_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_REGISTER_ACCESS_001: ctrl_register_access =====", UVM_NONE)

    // Step 1: Read CTRL register, verify reset value 0x0000_0071
    // Spec Table 6: TIMEOUT_VAL=3'b111 (bits[6:4]), ENABLE=1 (bit[0])
    check_reg_read("REG_ACCESS_001_RESET_VAL", 4'h0, 32'h0000_0071);

    // Step 2: Write 0x0000_0089 to CTRL (TIMEOUT_EN=1, ERR_INT_EN=1, ENABLE=1)
    drive_reg_write(4'h0, 32'h0000_0089);

    // Step 3: Read back CTRL, verify 0x0000_0089
    check_reg_read("REG_ACCESS_001_WRITE1", 4'h0, 32'h0000_0089);

    // Step 4: Write 0x0000_0039 to CTRL (TIMEOUT_VAL=011, ERR_INT_EN=1, ENABLE=1)
    drive_reg_write(4'h0, 32'h0000_0039);

    // Step 5: Read back CTRL, verify 0x0000_0039
    check_reg_read("REG_ACCESS_001_WRITE2", 4'h0, 32'h0000_0039);

    // Step 6: Restore default
    drive_reg_write(4'h0, 32'h0000_0071);

    print_summary("TEST_REGISTER_ACCESS_001");
  endtask
endclass
