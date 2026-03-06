// =============================================================================
// File        : ahb_mst_seq_item.sv
// Description : AHB Master Sequence Item (transaction descriptor)
//
// Encapsulates one AHB transfer:
//   - Address phase: HADDR, HTRANS, HWRITE, HSIZE, HBURST, HSEL
//   - Data phase:    HWDATA (write), HRDATA (read — captured by monitor)
//   - Response:      HRESP, HREADY_OUT
//
// Derivation:
//   - IP-XACT: signal names and widths
//   - Intent:  single transfers only (HTRANS=NONSEQ, HBURST=SINGLE)
//   - Tool:    No .randomize() — use $urandom / $urandom_range + post_randomize()
//
// Confidence: HIGH — standard AHB transaction fields.
// =============================================================================

class ahb_mst_seq_item extends uvm_sequence_item;
  `uvm_object_utils(ahb_mst_seq_item)

  // ----- Address-phase fields -----
  bit [31:0] HADDR;
  bit [ 1:0] HTRANS;  // 2'b10 = NONSEQ for single transfers
  bit        HWRITE;   // 1=write, 0=read
  bit [ 2:0] HSIZE;    // 3'b010 = 32-bit word
  bit [ 2:0] HBURST;   // 3'b000 = SINGLE
  bit        HSEL;     // Always 1 when targeting this bridge

  // ----- Data-phase fields -----
  bit [31:0] HWDATA;   // Write data (driven by driver in data phase)
  bit [31:0] HRDATA;   // Read data (captured by monitor)

  // ----- Response fields -----
  bit        HRESP;    // 0=OKAY, 1=ERROR
  bit        HREADY_OUT; // Captured at completion

  function new(string name = "ahb_mst_seq_item");
    super.new(name);
  endfunction

  // =========================================================================
  // post_randomize — called after manual field assignment to apply defaults
  // and constraints that would normally be in randomize() constraints.
  //
  // Per tool constraint [TC1]: no .randomize() in Questa FSE.
  // =========================================================================
  function void post_randomize();
    // For bringup: force single transfers
    HTRANS = 2'b10;   // NONSEQ
    HBURST = 3'b000;  // SINGLE
    HSIZE  = 3'b010;  // 32-bit word
    HSEL   = 1'b1;    // Always selected
  endfunction

  // =========================================================================
  // Utility: convert to string for UVM messaging
  // =========================================================================
  virtual function string convert2string();
    return $sformatf("HADDR=0x%08h %s HWDATA=0x%08h HRDATA=0x%08h HRESP=%0b",
                     HADDR,
                     HWRITE ? "WR" : "RD",
                     HWDATA,
                     HRDATA,
                     HRESP);
  endfunction

endclass