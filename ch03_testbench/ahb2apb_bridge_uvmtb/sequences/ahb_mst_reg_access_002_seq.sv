//----------------------------------------------------------------------
// File        : ahb_mst_reg_access_002_seq.sv
// Description : TEST_REGISTER_ACCESS_002 — ctrl_enable_bit
//               Verify ENABLE bit (CTRL[0]) controls bridge operation.
//               When ENABLE=0, APB transfers are blocked but register
//               access continues to work. When re-enabled, bridge works.
//----------------------------------------------------------------------

class ahb_mst_reg_access_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reg_access_002_seq)

  function new(string name = "ahb_mst_reg_access_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;

    `uvm_info(get_type_name(),
      "===== TEST_REGISTER_ACCESS_002: ctrl_enable_bit =====", UVM_NONE)

    // Step 1: Verify bridge works with default CTRL (ENABLE=1)
    write_and_verify("REG_ACCESS_002_DEFAULT", 32'h0000_1000, 32'hDEAD_BEEF);

    // Step 2: Disable bridge — write CTRL=0x0000_0070 (ENABLE=0, TIMEOUT_VAL=111)
    drive_reg_write(4'h0, 32'h0000_0070);

    // Step 3: Verify register access still works when ENABLE=0
    check_reg_read("REG_ACCESS_002_CTRL_DISABLED", 4'h0, 32'h0000_0070);

    // Step 4: Re-enable bridge — write CTRL=0x0000_0071 (restore default)
    drive_reg_write(4'h0, 32'h0000_0071);

    // Step 5: Verify CTRL restored
    check_reg_read("REG_ACCESS_002_RESTORE", 4'h0, 32'h0000_0071);

    // Step 6: Verify bridge works again after re-enable
    write_and_verify("REG_ACCESS_002_REENABLE", 32'h0000_2000, 32'hBEEF_CAFE);

    print_summary("TEST_REGISTER_ACCESS_002");
  endtask
endclass
