//----------------------------------------------------------------------
// File        : ahb_mst_error_005_seq.sv
// Description : TEST_ERROR_005 — timeout_value_configuration
//               Verify that different TIMEOUT_VAL settings affect timeout.
//               Spec TERR-3: timeout = 2^(TIMEOUT_VAL+4) cycles.
//               Test class sets pready_delay=20.
//               Phase 1: TIMEOUT_VAL=0 → 16 cycles → timeout (20>16)
//               Phase 2: TIMEOUT_VAL=1 → 32 cycles → no timeout (20<32)
//----------------------------------------------------------------------

class ahb_mst_error_005_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_005_seq)

  function new(string name = "ahb_mst_error_005_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_005: timeout_value_configuration =====", UVM_NONE)

    // ======== Phase 1: TIMEOUT_VAL=0 → 2^(0+4) = 16 cycles ========
    `uvm_info(get_type_name(), "--- Phase 1: TIMEOUT_VAL=0 (16 cycles, should timeout) ---", UVM_LOW)

    // CTRL: TIMEOUT_EN=1, TIMEOUT_VAL=000, ENABLE=1 → 0x0000_0081
    drive_reg_write(4'h0, 32'h0000_0081);

    // Write to 0x6000 — should timeout (pready_delay=20 > 16)
    drive_write_get_resp(32'h0000_6000, 32'h1111_2222, rdata, resp);
    check_resp("TVAL16_TIMEOUT", resp, 1'b1);

    // ======== Phase 2: TIMEOUT_VAL=1 → 2^(1+4) = 32 cycles ========
    `uvm_info(get_type_name(), "--- Phase 2: TIMEOUT_VAL=1 (32 cycles, should pass) ---", UVM_LOW)

    // CTRL: TIMEOUT_EN=1, TIMEOUT_VAL=001, ENABLE=1 → 0x0000_0091
    drive_reg_write(4'h0, 32'h0000_0091);

    // Write to 0x6004 — should complete (pready_delay=20 < 32)
    drive_write_get_resp(32'h0000_6004, 32'h3333_4444, rdata, resp);
    check_resp("TVAL32_NO_TIMEOUT", resp, 1'b0);

    print_summary("TEST_ERROR_005");
  endtask
endclass
