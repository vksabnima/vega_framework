// =============================================================================
// FILE: env/apb_slv_agent/apb_slv_sequencer.sv
// =============================================================================
// COMPONENT  : APB Slave Sequencer
// DESCRIPTION: Standard UVM sequencer for APB slave (reactive) transactions.
//
// DERIVED FROM:
//   - Standard UVM methodology.
//
// CONFIDENCE: HIGH — standard parameterized sequencer.
// =============================================================================

class apb_slv_sequencer extends uvm_sequencer #(apb_slv_seq_item);

  `uvm_component_utils(apb_slv_sequencer)

  function new(string name = "apb_slv_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction : new

endclass : apb_slv_sequencer