//----------------------------------------------------------------------
// File        : ahb_mst_reg_access_003_seq.sv
// Description : TEST_REGISTER_ACCESS_003 — status_register_access
//               Read STATUS register and verify reset value.
//               Spec Table 7: bit[0]=READY=1 when idle, bit[1]=BUSY=0.
//               Reset value = 0x0000_0001. STATUS supports W1C for
//               error bits [7:4].
//----------------------------------------------------------------------

class ahb_mst_reg_access_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_reg_access_003_seq)

  function new(string name = "ahb_mst_reg_access_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_REGISTER_ACCESS_003: status_register_access =====", UVM_NONE)

    // Step 1: Read STATUS register in idle, verify READY=1 → 0x0000_0001
    check_reg_read("REG_ACCESS_003_RESET_VAL", 4'h4, 32'h0000_0001);

    // Step 2: Generate an address error to set STATUS.ADDR_ERR (bit[4])
    drive_write_get_resp(32'h0001_0000, 32'hBAD0_ADD0, rdata, resp);

    // Step 3: Read STATUS, verify ADDR_ERR=1 → bit[4]=1, READY=1 → 0x0000_0011
    check_reg_read("REG_ACCESS_003_ADDR_ERR", 4'h4, 32'h0000_0011);

    // Step 4: W1C — write 0x0000_0010 to STATUS to clear ADDR_ERR
    drive_reg_write(4'h4, 32'h0000_0010);

    // Step 5: Read STATUS, verify ADDR_ERR cleared → 0x0000_0001
    check_reg_read("REG_ACCESS_003_W1C_CLEAR", 4'h4, 32'h0000_0001);

    print_summary("TEST_REGISTER_ACCESS_003");
  endtask
endclass
