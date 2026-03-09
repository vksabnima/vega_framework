//----------------------------------------------------------------------
// File        : ahb_mst_error_006_seq.sv
// Description : TEST_ERROR_006 — protocol_error_detection
//               Verify the bridge detects PSLVERR from the APB slave.
//               The test class sets pslverr_inject=1 on the APB driver.
//               A write to a valid address should result in HRESP=1 and
//               correct ERROR_ADDR / ERROR_INFO capture.
//----------------------------------------------------------------------

class ahb_mst_error_006_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_error_006_seq)

  function new(string name = "ahb_mst_error_006_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_ERROR_006: protocol_error_detection =====", UVM_NONE)

    // ---- Step 1: Write to 0x6000 with PSLVERR injected ----
    drive_write_get_resp(32'h0000_6000, 32'h8765_4321, rdata, resp);
    check_resp("PSLVERR_WRITE", resp, 1'b1);

    // ---- Step 2: Read ERROR_ADDR (offset 0x8), expect 0x0000_6000 ----
    check_reg_read("ERROR_ADDR", 4'h8, 32'h0000_6000);

    // ---- Step 3: Read ERROR_INFO (offset 0xC) ----
    // Spec Table 9/10: ERR_TYPE=3(PSLVERR), ERR_WRITE=1, ERR_SIZE=010 → 0x003A
    check_reg_read("ERROR_INFO", 4'hC, 32'h0000_003A);

    // ---- Step 4: Clear errors, then read with PSLVERR (coverage: READ+PSLVERR) ----
    drive_reg_write(4'h4, 32'h00F0);  // Clear all error bits
    begin
      bit [31:0] rd;
      bit        rsp;
      drive_read(32'h0000_6000, rd, rsp);
      check_resp("PSLVERR_READ", rsp, 1'b1);
    end

    print_summary("TEST_ERROR_006");
  endtask
endclass
