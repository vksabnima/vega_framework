// =============================================================================
// FILE: env/ahb_mst_agent/ahb_mst_seq_item.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence Item (Transaction)
// DESCRIPTION: Represents a single AHB transaction. Used by the AHB master
//              driver to drive stimulus and by the AHB monitor to capture
//              observed transactions.
//
// DERIVED FROM:
//   - IP-XACT: Signal names and widths for HADDR, HTRANS, HWRITE, HSIZE,
//              HBURST, HWDATA, HRDATA, HRESP.
//   - Intent: Single transfers only (HTRANS=NONSEQ, HBURST=SINGLE).
//   - Spec: Section 3.1 and 5.1 for transfer fields.
//
// CONFIDENCE: HIGH — fields directly map to IP-XACT port definitions.
//
// NOTE: No rand qualifier used — we use $urandom_range per [TC1].
// =============================================================================

class ahb_mst_seq_item extends uvm_sequence_item;

  `uvm_object_utils(ahb_mst_seq_item)

  // ── Transaction fields (from IP-XACT signal widths) ──────────────────────

  // AHB address — 32 bits [IP-XACT: HADDR[31:0]]
  logic [31:0] addr;

  // AHB transfer type — 2 bits [IP-XACT: HTRANS[1:0]]
  // 00=IDLE, 01=BUSY, 10=NONSEQ, 11=SEQ
  logic [1:0]  trans_type;

  // AHB direction — 1 bit [IP-XACT: HWRITE]
  // 1=write, 0=read
  logic        write;

  // AHB transfer size — 3 bits [IP-XACT: HSIZE[2:0]]
  // 010=word for this bringup
  logic [2:0]  size;

  // AHB burst type — 3 bits [IP-XACT: HBURST[2:0]]
  // 000=SINGLE for this bringup
  logic [2:0]  burst;

  // AHB write data — 32 bits [IP-XACT: HWDATA[31:0]]
  logic [31:0] wdata;

  // ── Response fields (captured by monitor, not driven by sequences) ───────

  // AHB read data — 32 bits [IP-XACT: HRDATA[31:0]]
  logic [31:0] rdata;

  // AHB response — 1 bit [IP-XACT: HRESP]
  // 0=OKAY, 1=ERROR
  logic        resp;

  function new(string name = "ahb_mst_seq_item");
    super.new(name);
    // Default values — safe single word transfer
    addr       = 32'h0;
    trans_type = 2'b10;   // NONSEQ — start of single transfer
    write      = 1'b0;    // Read by default
    size       = 3'b010;  // Word size (32-bit)
    burst      = 3'b000;  // SINGLE burst
    wdata      = 32'h0;
    rdata      = 32'h0;
    resp       = 1'b0;    // OKAY
  endfunction : new

  // post_randomize sets sensible defaults for fields not explicitly set.
  // Called after manual field assignment in sequences.
  function void post_randomize();
    // For bringup: always SINGLE burst, word-size, NONSEQ
    // EDIT_OPTIONAL: Override these if testing bursts or different sizes
    burst      = 3'b000;  // SINGLE
    size       = 3'b010;  // Word
    trans_type = 2'b10;   // NONSEQ
  endfunction : post_randomize

  // Convert to string for UVM reporting
  function string convert2string();
    return $sformatf("AHB TXN: addr=0x%08h %s wdata=0x%08h rdata=0x%08h resp=%0b trans=0b%02b burst=0b%03b size=0b%03b",
                     addr,
                     write ? "WR" : "RD",
                     wdata, rdata, resp, trans_type, burst, size);
  endfunction : convert2string

endclass : ahb_mst_seq_item