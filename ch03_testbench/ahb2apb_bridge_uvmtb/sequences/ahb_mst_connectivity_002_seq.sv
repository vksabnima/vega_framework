//----------------------------------------------------------------------
// File        : ahb_mst_connectivity_002_seq.sv
// Description : TEST_CONNECTIVITY_002 — ahb_wait_state_stability
//               Verify control signals remain stable during wait states.
//               APB slave driver will have pready_delay set by the test.
//               Drives a single write, checks HRESP, then reads back to
//               confirm data integrity despite wait-state insertion.
//----------------------------------------------------------------------

class ahb_mst_connectivity_002_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_connectivity_002_seq)

  function new(string name = "ahb_mst_connectivity_002_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;
    bit        resp;

    `uvm_info(get_type_name(),
      "===== TEST_CONNECTIVITY_002: Wait state stability =====", UVM_NONE)

    // Write with wait states (pready_delay set by test)
    drive_write_get_resp(32'h0000_1000, 32'hABCD_1234, rdata, resp);
    check_resp("CONN_002_WRITE", resp, 1'b0);

    // Verify data written correctly despite wait states
    check_read("CONN_002_READBACK", 32'h0000_1000, 32'hABCD_1234);

    print_summary("TEST_CONNECTIVITY_002");
  endtask
endclass
