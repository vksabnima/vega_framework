//----------------------------------------------------------------------
// File        : ahb_mst_protocol_001_seq.sv
// Description : TEST_PROTOCOL_001 — apb_wait_state_propagation
//               Verify that AHB write/read completes correctly when
//               APB slave inserts wait states (pready_delay > 0).
//               Data integrity must be maintained despite wait states.
//----------------------------------------------------------------------

class ahb_mst_protocol_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_protocol_001_seq)

  function new(string name = "ahb_mst_protocol_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_PROTOCOL_001: apb_wait_state_propagation =====", UVM_NONE)

    `uvm_info(get_type_name(),
      "NOTE: APB slave pready_delay is configured by the test (e.g., 3 cycles).", UVM_MEDIUM)

    // Step 1: Write 0x5555_AAAA to address 0x5000
    `uvm_info(get_type_name(),
      "Step 1: Write 0x5555_AAAA to 0x5000 (with APB wait states)", UVM_MEDIUM)
    drive_write_get_resp(32'h0000_5000, 32'h5555_AAAA, rdata, resp);

    // Step 2: Verify HRESP=0 (OKAY) despite wait states
    check_resp("PROTOCOL_001_WRITE_RESP", resp, 1'b0);

    // Step 3: Read back from 0x5000 and verify data integrity
    `uvm_info(get_type_name(),
      "Step 2: Read back from 0x5000, verify data integrity", UVM_MEDIUM)
    check_read("PROTOCOL_001_READBACK", 32'h0000_5000, 32'h5555_AAAA);

    `uvm_info(get_type_name(),
      "Transfer completed successfully despite APB wait states.", UVM_MEDIUM)

    print_summary("TEST_PROTOCOL_001");
  endtask
endclass
