// =============================================================================
// FILE: sequences/apb_slv_bringup_seq.sv
// =============================================================================
// COMPONENT  : APB Slave Bringup Sequence (Reactive)
// DESCRIPTION: Reactive sequence that runs on the APB slave sequencer.
//              Creates response items for the APB slave driver to process.
//              Runs in a forever loop — each iteration produces one
//              response to a DUT-initiated APB transfer.
//
// DERIVED FROM:
//   - Intent (DRIVE): "APB slave agent should behave as a simple memory slave.
//     Respond to every APB transaction with PREADY asserted after one clock.
//     No error responses."
//   - Rule [U3]: Passive/reactive sequences use forever loop, not repeat().
//
// ARCHITECTURE:
//   The reactive sequence simply creates items and sends them to the driver.
//   The driver handles the actual protocol handshaking and memory model.
//   The sequence acts as an item factory for the reactive driver.
//
// CONFIDENCE: HIGH — simple reactive sequence pattern.
// =============================================================================

class apb_slv_bringup_seq extends uvm_sequence #(apb_slv_seq_item);

  `uvm_object_utils(apb_slv_bringup_seq)

  function new(string name = "apb_slv_bringup_seq");
    super.new(name);
  endfunction : new

  task body();
    apb_slv_seq_item req;

    `uvm_info("APB_SEQ", "Starting APB slave reactive sequence (forever loop)", UVM_MEDIUM)

    // Forever loop [U3] — reactive slave runs continuously
    // Each iteration creates one response item for the driver
    forever begin
      req = apb_slv_seq_item::type_id::create("apb_resp");

      start_item(req);

      // Default response: ready, no error
      // Intent: "PREADY asserted after one clock cycle. No error responses."
      req.slverr = 1'b0;
      req.ready  = 1'b1;
      req.rdata  = 32'h0;  // Driver will fill in from memory model

      finish_item(req);
    end
  endtask : body

endclass : apb_slv_bringup_seq