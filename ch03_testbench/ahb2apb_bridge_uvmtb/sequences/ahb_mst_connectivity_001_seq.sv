//----------------------------------------------------------------------
// File        : ahb_mst_connectivity_001_seq.sv
// Description : TEST_CONNECTIVITY_001 — ahb_idle_hready_high
//               Verify HREADY_OUT is HIGH when bridge is in IDLE state.
//               No AHB transactions are driven; the test class observes
//               HREADY_OUT directly via the virtual interface.
//----------------------------------------------------------------------

class ahb_mst_connectivity_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_connectivity_001_seq)

  function new(string name = "ahb_mst_connectivity_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_CONNECTIVITY_001: IDLE HREADY_OUT check =====", UVM_NONE)

    // No AHB transactions — test class observes HREADY_OUT directly
    `uvm_info(get_type_name(), "Sequence complete (idle observation test)", UVM_NONE)
  endtask
endclass
