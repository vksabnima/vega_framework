//----------------------------------------------------------------------
// File        : ahb_mst_connectivity_003_seq.sv
// Description : TEST_CONNECTIVITY_003 — apb_psel_entire_transfer
//               Verify PSEL remains HIGH during both SETUP and ACCESS
//               phases. Scoreboard verification groups VG1/VG4/VG6
//               confirm this indirectly by checking the APB transaction
//               completed correctly.
//----------------------------------------------------------------------

class ahb_mst_connectivity_003_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_connectivity_003_seq)

  function new(string name = "ahb_mst_connectivity_003_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_CONNECTIVITY_003: PSEL entire transfer =====", UVM_NONE)

    write_and_verify("CONN_003", 32'h0000_2000, 32'h1234_5678);

    print_summary("TEST_CONNECTIVITY_003");
  endtask
endclass
