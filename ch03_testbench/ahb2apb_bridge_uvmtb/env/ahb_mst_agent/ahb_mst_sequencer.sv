// =============================================================================
// File        : ahb_mst_sequencer.sv
// Description : AHB Master Sequencer
//
// Standard UVM sequencer — no custom logic needed for bringup/sanity tests.
// Passes ahb_mst_seq_item between sequence and driver.
//
// Confidence: HIGH — boilerplate UVM sequencer.
// =============================================================================

class ahb_mst_sequencer extends uvm_sequencer #(ahb_mst_seq_item);
  `uvm_component_utils(ahb_mst_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass