// =============================================================================
// File        : apb_slv_bringup_seq.sv
// Description : APB Slave Bringup Sequence (placeholder)
//
// In the current architecture, the APB slave driver handles reactive
// behavior directly (embedded memory model) without sequences.
// This file is provided as a placeholder for future sequence-driven
// reactive implementations.
//
// Per [U3]: reactive sequences use `forever` loop, not `repeat()`.
//
// Confidence: HIGH — placeholder with correct structure.
//
// EDIT_OPTIONAL: If you convert the APB slave driver to use sequences,
//   implement the reactive memory model here instead of in the driver.
// =============================================================================

class apb_slv_bringup_seq extends uvm_sequence #(apb_slv_seq_item);
  `uvm_object_utils(apb_slv_bringup_seq)

  function new(string name = "apb_slv_bringup_seq");
    super.new(name);
  endfunction

  // =========================================================================
  // body — placeholder for reactive slave sequence
  //
  // Per [U3]: use forever loop for reactive/passive sequences.
  // Currently not used because the driver handles reactive behavior.
  // =========================================================================
  virtual task body();
    // Placeholder: reactive sequence not used in bringup
    // If activated, would look like:
    //
    // forever begin
    //   apb_slv_seq_item req;
    //   req = apb_slv_seq_item::type_id::create("req");
    //   start_item(req);
    //   // Populate response fields based on observed DUT signals
    //   req.PREADY  = 1'b1;
    //   req.PSLVERR = 1'b0;
    //   req.PRDATA  = 32'hDEAD_BEEF; // From memory model
    //   req.post_randomize();
    //   finish_item(req);
    // end

    `uvm_info("APB_SLV_SEQ", "APB slave sequence placeholder — not used in bringup", UVM_LOW)
  endtask

endclass