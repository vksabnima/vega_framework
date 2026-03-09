//----------------------------------------------------------------------
// File        : ahb_mst_connectivity_004_seq.sv
// Description : TEST_CONNECTIVITY_004 — apb_penable_phases
//               Verify PENABLE transitions correctly between SETUP and
//               ACCESS phases. Scoreboard verification groups VG3 (read
//               data) and VG4 (direction) confirm this indirectly.
//----------------------------------------------------------------------

class ahb_mst_connectivity_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_connectivity_004_seq)

  function new(string name = "ahb_mst_connectivity_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_CONNECTIVITY_004: PENABLE phases =====", UVM_NONE)

    write_and_verify("CONN_004", 32'h0000_3000, 32'hFEDC_BA98);

    print_summary("TEST_CONNECTIVITY_004");
  endtask
endclass
