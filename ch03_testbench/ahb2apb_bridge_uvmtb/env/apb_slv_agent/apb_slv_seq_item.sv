// =============================================================================
// File        : apb_slv_seq_item.sv
// Description : APB Slave Sequence Item (transaction descriptor)
//
// Represents one APB transfer as seen/driven by the reactive slave agent:
//   - PADDR, PSEL, PENABLE, PWRITE, PWDATA (from DUT, observed by slave)
//   - PRDATA, PREADY, PSLVERR (driven by slave back to DUT)
//
// Derivation:
//   - IP-XACT: signal names from APB master interface ports
//   - Intent:  slave stores writes, returns data on reads, no errors
//
// Confidence: HIGH — standard APB2 transaction fields.
// =============================================================================

class apb_slv_seq_item extends uvm_sequence_item;
  `uvm_object_utils(apb_slv_seq_item)

  // ----- Signals from DUT (observed by slave) -----
  bit [31:0] PADDR;
  bit        PSEL;
  bit        PENABLE;
  bit        PWRITE;
  bit [31:0] PWDATA;

  // ----- Signals driven by slave to DUT -----
  bit [31:0] PRDATA;
  bit        PREADY;
  bit        PSLVERR;

  function new(string name = "apb_slv_seq_item");
    super.new(name);
  endfunction

  // =========================================================================
  // post_randomize — apply defaults for bringup
  // No errors, PREADY always asserted.
  // =========================================================================
  function void post_randomize();
    PREADY  = 1'b1;
    PSLVERR = 1'b0;
  endfunction

  virtual function string convert2string();
    return $sformatf("PADDR=0x%08h %s PWDATA=0x%08h PRDATA=0x%08h PSLVERR=%0b",
                     PADDR,
                     PWRITE ? "WR" : "RD",
                     PWDATA,
                     PRDATA,
                     PSLVERR);
  endfunction

endclass