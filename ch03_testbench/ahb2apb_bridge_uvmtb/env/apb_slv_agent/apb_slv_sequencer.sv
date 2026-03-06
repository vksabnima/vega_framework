// =============================================================================
// File        : apb_slv_sequencer.sv
// Description : APB Slave Sequencer
//
// Standard UVM sequencer for the reactive APB slave agent.
// In the current bringup implementation, the driver handles reactive
// behavior directly without using sequences.  This sequencer is
// instantiated for structural completeness and future extensibility.
//
// Confidence: HIGH — boilerplate UVM sequencer.
// =============================================================================

class apb_slv_sequencer extends uvm_sequencer #(apb_slv_seq_item);
  `uvm_component_utils(apb_slv_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass