// =============================================================================
// FILE: env/ahb_mst_agent/ahb_mst_sequencer.sv
// =============================================================================
// COMPONENT  : AHB Master Sequencer
// DESCRIPTION: Standard UVM sequencer for AHB master transactions.
//              Routes ahb_mst_seq_item between sequences and driver.
//
// DERIVED FROM:
//   - Standard UVM methodology — no special configuration needed.
//
// CONFIDENCE: HIGH — this is a standard parameterized sequencer.
// =============================================================================

class ahb_mst_sequencer extends uvm_sequencer #(ahb_mst_seq_item);

  `uvm_component_utils(ahb_mst_sequencer)

  function new(string name = "ahb_mst_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction : new

endclass : ahb_mst_sequencer