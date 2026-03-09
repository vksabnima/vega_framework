//----------------------------------------------------------------------
// File        : ahb_mst_error_010_seq.sv
// Description : TEST_ERROR_010 — multiple_errors_first_captured (ERPT-6)
//               Verify that ERROR_ADDR/ERROR_INFO lock on first error
//               and only update after the error bits are cleared via W1C.
//----------------------------------------------------------------------

class ahb_mst_error_010_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_010_seq)

  function new(string name = "ahb_mst_error_010_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_010: multiple_errors_first_captured =====", UVM_NONE)

    // ---- Step 1: Generate first error — write to 0x0010_0000 ----
    drive_write_get_resp(32'h0010_0000, 32'h1111_1111, rdata, resp);
    check_resp("FIRST_ERR", resp, 1'b1);

    // ---- Step 2: Read ERROR_ADDR, expect 0x0010_0000 ----
    check_reg_read("FIRST_ERROR_ADDR", 4'h8, 32'h0010_0000);

    // ---- Step 3: Read ERROR_INFO — ERR_TYPE=1(addr), ERR_WRITE=1, ERR_SIZE=010 → 0x001A ----
    check_reg_read("FIRST_ERROR_INFO", 4'hC, 32'h0000_001A);

    // ---- Step 4: Generate second error WITHOUT clearing — write to 0x0020_0000 ----
    drive_write_get_resp(32'h0020_0000, 32'h2222_2222, rdata, resp);
    check_resp("SECOND_ERR", resp, 1'b1);

    // ---- Step 5: ERROR_ADDR should STILL be 0x0010_0000 (first error locked) ----
    check_reg_read("LOCKED_ERROR_ADDR", 4'h8, 32'h0010_0000);

    // ---- Step 6: ERROR_INFO should STILL be 0x001A (first error locked) ----
    check_reg_read("LOCKED_ERROR_INFO", 4'hC, 32'h0000_001A);

    // ---- Step 7: Clear error via W1C — clear ADDR_ERR (bit[4]) ----
    drive_reg_write(4'h4, 32'h0000_0010);

    // ---- Step 8: Generate third error — write to 0x0030_0000 ----
    drive_write_get_resp(32'h0030_0000, 32'h3333_3333, rdata, resp);
    check_resp("THIRD_ERR", resp, 1'b1);

    // ---- Step 9: ERROR_ADDR NOW should be 0x0030_0000 (lock released) ----
    check_reg_read("UNLOCKED_ERROR_ADDR", 4'h8, 32'h0030_0000);

    print_summary("TEST_ERROR_010");
  endtask
endclass
