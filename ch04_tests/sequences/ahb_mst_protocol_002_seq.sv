//----------------------------------------------------------------------
// File        : ahb_mst_protocol_002_seq.sv
// Description : TEST_PROTOCOL_002 — minimum_apb_transfer_cycles
//               Verify minimum 2-cycle APB transfer with no wait states
//               (pready_delay=0). Write and read back to confirm data
//               integrity under zero-latency APB slave conditions.
//----------------------------------------------------------------------

class ahb_mst_protocol_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_protocol_002_seq)

  function new(string name = "ahb_mst_protocol_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_PROTOCOL_002: minimum_apb_transfer_cycles =====", UVM_NONE)

    `uvm_info(get_type_name(),
      "NOTE: APB slave pready_delay=0 (no wait states). Minimum 2-cycle APB transfer.", UVM_MEDIUM)

    // Step 1: Write 0x1122_3344 to address 0x6000
    `uvm_info(get_type_name(),
      "Step 1: Write 0x1122_3344 to 0x6000 (zero wait states)", UVM_MEDIUM)
    drive_write_get_resp(32'h0000_6000, 32'h1122_3344, rdata, resp);

    // Step 2: Verify HRESP=0 (OKAY)
    check_resp("PROTOCOL_002_WRITE_RESP", resp, 1'b0);

    // Step 3: Read back from 0x6000 and verify data
    `uvm_info(get_type_name(),
      "Step 2: Read back from 0x6000, verify data integrity", UVM_MEDIUM)
    check_read("PROTOCOL_002_READBACK", 32'h0000_6000, 32'h1122_3344);

    print_summary("TEST_PROTOCOL_002");
  endtask
endclass
