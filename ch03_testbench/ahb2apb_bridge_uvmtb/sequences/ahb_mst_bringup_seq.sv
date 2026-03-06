// =============================================================================
// File        : ahb_mst_bringup_seq.sv
// Description : AHB Master Bringup Sequence
//
// Drives a configurable number of simple single AHB transactions.
// Uses $urandom / $urandom_range per [TC1] — no .randomize().
//
// For bringup_test:  num_txns = 1  (prove infrastructure works)
// For sanity_test:   num_txns = 5  (from manifest, exercise all VGs)
//
// Address range: 0x0000_0000 to 0x0000_0EFF (APB range excluding register
//   block 0x0F00–0x0F0F to avoid register accesses in bringup).
//
// EDIT_RECOMMENDED: Adjust address range if DUT address decode differs.
//
// Derivation:
//   - Intent: "mix of read and write transactions, random addresses within
//             valid APB range, random data values for writes"
//   - Manifest: num_txns=5
//   - IP-XACT: APB range 0–0xFFFF, REG_BASE=0x0F00
//
// Confidence: HIGH — simple sequence with manual randomization.
// =============================================================================

class ahb_mst_bringup_seq extends uvm_sequence #(ahb_mst_seq_item);
  `uvm_object_utils(ahb_mst_bringup_seq)

  // Number of transactions to drive
  int num_txns = 1;

  function new(string name = "ahb_mst_bringup_seq");
    super.new(name);
  endfunction

  virtual task body();
    ahb_mst_seq_item req;
    bit [31:0] addr;

    `uvm_info("AHB_SEQ", $sformatf("Starting sequence with %0d transactions", num_txns), UVM_LOW)

    for (int i = 0; i < num_txns; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("req_%0d", i));

      // ----- Manual randomization per [TC1] -----
      // Generate address in valid APB range, avoiding register block
      // APB range: 0x0000 to 0xFFFF
      // Register block: 0x0F00 to 0x0F0F (avoid)
      // Strategy: generate address, if in reg range shift it
      addr = $urandom_range(0, 32'h0000_0EFF);
      // Word-align the address (HSIZE=word → bits [1:0] = 0)
      addr = {addr[31:2], 2'b00};

      req.HADDR  = addr;
      req.HWRITE = $urandom_range(0, 1);  // Random read or write
      req.HWDATA = {$urandom, $urandom};  // Random 32-bit data
      // EDIT_OPTIONAL: $urandom returns 32 bits; using just $urandom is fine
      req.HWDATA = $urandom;

      // Apply defaults via post_randomize (HTRANS=NONSEQ, HBURST=SINGLE, etc.)
      req.post_randomize();

      `uvm_info("AHB_SEQ", $sformatf("Txn[%0d]: %s", i, req.convert2string()), UVM_MEDIUM)

      start_item(req);
      finish_item(req);

      `uvm_info("AHB_SEQ", $sformatf("Txn[%0d] done: %s", i, req.convert2string()), UVM_MEDIUM)
    end

    `uvm_info("AHB_SEQ", "Sequence complete", UVM_LOW)
  endtask

endclass