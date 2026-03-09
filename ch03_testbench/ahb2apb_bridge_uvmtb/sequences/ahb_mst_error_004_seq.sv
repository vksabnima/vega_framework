//----------------------------------------------------------------------
// File        : ahb_mst_error_004_seq.sv
// Description : TEST_ERROR_004 — timeout_enable_control
//               Verify that timeout detection is gated by TIMEOUT_EN.
//               Phase 1: TIMEOUT_EN=0 → no timeout despite long delay.
//               Phase 2: TIMEOUT_EN=1 → timeout occurs.
//               Test class sets pready_delay=25 on the APB driver.
//----------------------------------------------------------------------

class ahb_mst_error_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_004_seq)

  function new(string name = "ahb_mst_error_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_004: timeout_enable_control =====", UVM_NONE)

    // ======== Phase 1: Timeout DISABLED ========
    `uvm_info(get_type_name(), "--- Phase 1: TIMEOUT_EN=0 ---", UVM_LOW)

    // CTRL: TIMEOUT_EN=0, TIMEOUT_VAL=0, ENABLE=1 → 0x0000_0001
    drive_reg_write(4'h0, 32'h0000_0001);

    // Write to 0x5000 — should complete normally (timeout disabled)
    drive_write_get_resp(32'h0000_5000, 32'hA5A5_A5A5, rdata, resp);
    check_resp("PHASE1_NO_TIMEOUT", resp, 1'b0);

    // ======== Phase 2: Timeout ENABLED ========
    `uvm_info(get_type_name(), "--- Phase 2: TIMEOUT_EN=1 ---", UVM_LOW)

    // CTRL: TIMEOUT_EN=1, TIMEOUT_VAL=0 (16 cycles), ENABLE=1 → 0x0000_0081
    drive_reg_write(4'h0, 32'h0000_0081);

    // Write to 0x5004 — should timeout (pready_delay=25 > 16 cycles)
    drive_write_get_resp(32'h0000_5004, 32'h5A5A_5A5A, rdata, resp);
    check_resp("PHASE2_TIMEOUT", resp, 1'b1);

    print_summary("TEST_ERROR_004");
  endtask
endclass
