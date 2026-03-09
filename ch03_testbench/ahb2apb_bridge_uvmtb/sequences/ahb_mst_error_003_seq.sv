//----------------------------------------------------------------------
// File        : ahb_mst_error_003_seq.sv
// Description : TEST_ERROR_003 — timeout_error_detection
//               Verify timeout detection when APB slave delays PREADY
//               beyond the configured timeout limit.  The test class sets
//               pready_delay=20 on the APB driver.
//               CTRL: TIMEOUT_EN=1 (bit[7]), TIMEOUT_VAL=0 (bits[6:4])
//               → 2^(0+4) = 16 cycles.  20 > 16 → timeout.
//----------------------------------------------------------------------

class ahb_mst_error_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_003_seq)

  function new(string name = "ahb_mst_error_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_003: timeout_error_detection =====", UVM_NONE)

    // ---- Step 1: Configure CTRL — TIMEOUT_EN=1, TIMEOUT_VAL=0, ENABLE=1 ----
    // Spec Table 6: bit[7]=TIMEOUT_EN, bits[6:4]=TIMEOUT_VAL, bit[0]=ENABLE
    // 0x0000_0081 → TIMEOUT_EN=1, TIMEOUT_VAL=000 (16 cycles), ENABLE=1
    drive_reg_write(4'h0, 32'h0000_0081);

    // ---- Step 2: Write to 0x4000 — should timeout (pready_delay=20 > 16) ----
    drive_write_get_resp(32'h0000_4000, 32'hFEED_FACE, rdata, resp);
    check_resp("TIMEOUT_WRITE", resp, 1'b1);

    // ---- Step 3: Read ERROR_ADDR (offset 0x8), expect 0x0000_4000 ----
    check_reg_read("ERROR_ADDR", 4'h8, 32'h0000_4000);

    // ---- Step 4: Read ERROR_INFO (offset 0xC) ----
    // Spec Table 9/10: ERR_TYPE=2(timeout), ERR_WRITE=1, ERR_SIZE=010 → 0x002A
    check_reg_read("ERROR_INFO", 4'hC, 32'h0000_002A);

    print_summary("TEST_ERROR_003");
  endtask
endclass
