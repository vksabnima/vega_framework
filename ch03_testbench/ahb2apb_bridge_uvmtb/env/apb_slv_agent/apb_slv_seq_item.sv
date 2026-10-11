// =============================================================================
// FILE: env/apb_slv_agent/apb_slv_seq_item.sv
// =============================================================================
// COMPONENT  : APB Slave Sequence Item (Transaction)
// DESCRIPTION: Represents a single APB transaction. Used by the APB slave
//              driver (reactive) to respond to DUT-initiated APB transfers,
//              and by the APB monitor to capture observed transactions.
//
// DERIVED FROM:
//   - IP-XACT: Signal names and widths for PADDR, PSEL, PENABLE, PWRITE,
//              PWDATA, PRDATA, PREADY, PSLVERR.
//   - Intent: "APB slave should behave as simple memory slave. Respond with
//              PREADY after one clock. No error responses."
//
// CONFIDENCE: HIGH — fields map directly to IP-XACT port definitions.
// =============================================================================

class apb_slv_seq_item extends uvm_sequence_item;

  `uvm_object_utils(apb_slv_seq_item)

  // ── Transaction fields (from IP-XACT signal widths) ──────────────────────

  // APB address — 32 bits [IP-XACT: PADDR[31:0]]
  logic [31:0] addr;

  // APB direction — 1 bit [IP-XACT: PWRITE]
  logic        write;

  // APB write data — 32 bits [IP-XACT: PWDATA[31:0]]
  logic [31:0] wdata;

  // APB read data — 32 bits [IP-XACT: PRDATA[31:0]]
  // For reactive slave: this is the data to return on reads
  logic [31:0] rdata;

  // APB slave error — 1 bit [IP-XACT: PSLVERR]
  // For reactive slave: error response to return
  logic        slverr;

  // APB ready — 1 bit [IP-XACT: PREADY]
  // For reactive slave: when to assert ready
  logic        ready;

  function new(string name = "apb_slv_seq_item");
    super.new(name);
    addr   = 32'h0;
    write  = 1'b0;
    wdata  = 32'h0;
    rdata  = 32'h0;
    slverr = 1'b0;    // No error — intent says "no error responses"
    ready  = 1'b1;    // Ready after one cycle — intent says "PREADY after one clock"
  endfunction : new

  function void post_randomize();
    // No special processing needed for bringup
  endfunction : post_randomize

  function string convert2string();
    return $sformatf("APB TXN: addr=0x%08h %s wdata=0x%08h rdata=0x%08h slverr=%0b",
                     addr,
                     write ? "WR" : "RD",
                     wdata, rdata, slverr);
  endfunction : convert2string

endclass : apb_slv_seq_item