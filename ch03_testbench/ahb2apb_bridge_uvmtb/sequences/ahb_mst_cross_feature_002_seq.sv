//----------------------------------------------------------------------
// File        : ahb_mst_cross_feature_002_seq.sv
// Description : TEST_CROSS_FEATURE_002 — timeout_error_during_register_access
//               Configure timeout (TIMEOUT_EN=1, TIMEOUT_VAL=0 → 16 cycles),
//               drive write to APB address where pready_delay=20 (set by
//               test), expect timeout and HRESP=1. Verify register access
//               unaffected after timeout.
//----------------------------------------------------------------------

class ahb_mst_cross_feature_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_cross_feature_002_seq)

  function new(string name = "ahb_mst_cross_feature_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_CROSS_FEATURE_002: timeout_error_during_register_access =====", UVM_NONE)

    // ---- Step 1: Write CTRL: TIMEOUT_EN=1, TIMEOUT_VAL=0, ENABLE=1 → 0x0000_0081 ----
    `uvm_info(get_type_name(),
      "Step 1: Write CTRL = 0x0000_0081 (TIMEOUT_EN=1, 16-cycle timeout, ENABLE=1)", UVM_MEDIUM)
    drive_reg_write(4'h0, 32'h0000_0081);

    // ---- Step 2: Write to 0x4000 (APB slave pready_delay=20 > timeout=16) ----
    `uvm_info(get_type_name(),
      "Step 2: Write to 0x4000 — expect timeout (pready_delay=20 > 16)", UVM_MEDIUM)
    drive_write_get_resp(32'h0000_4000, 32'hBAD0_DA1A, rdata, resp);

    // ---- Step 3: Check HRESP=1 (error due to timeout) ----
    check_resp("XFEAT_002_TIMEOUT_RESP", resp, 1'b1);

    // ---- Step 4: Read CTRL, verify still 0x0000_0081 (register unaffected) ----
    check_reg_read("XFEAT_002_CTRL_INTACT", 4'h0, 32'h0000_0081);

    // ---- Step 5: Read ERROR_ADDR, expect 0x0000_4000 ----
    check_reg_read("XFEAT_002_ERROR_ADDR", 4'h8, 32'h0000_4000);

    print_summary("TEST_CROSS_FEATURE_002");
  endtask
endclass
