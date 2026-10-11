// =============================================================================
// FILE: sequences/ahb_mst_bringup_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Bringup Sequence
// DESCRIPTION: Drives a configurable number of simple AHB transactions.
//              For bringup_test: 1 transaction. For sanity_test: num_txns.
//              Uses random addresses within APB range, random data, mix of
//              read/write.
//
// DERIVED FROM:
//   - Intent (DRIVE): "Drive a mix of read and write transactions into the
//     bridge. Use random addresses within the valid APB address range.
//     Use random data values for writes. Keep transactions simple — single
//     transfers only, no bursts."
//   - IP-XACT: APB_ADDR_START=0x0000_0000, APB_ADDR_END=0x0000_FFFF,
//     REG_BASE=0x0000_0F00 (avoid register range for normal APB transfers).
//   - Manifest: num_txns=5.
//
// NOTE: No .randomize() — uses $urandom_range per [TC1].
//
// CONFIDENCE: HIGH — straightforward stimulus generation.
// =============================================================================

class ahb_mst_bringup_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_bringup_seq)

  // Number of transactions to drive — set by test
  int unsigned num_txns = 1;

  function new(string name = "ahb_mst_bringup_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    int unsigned i;
    // Remember each write so we can read the SAME address back and confirm the
    // stored data round-trips through the bridge (VG2 write + VG3 read-back).
    logic [31:0] wr_addr [];
    logic [31:0] wr_data [];

    wr_addr = new[num_txns];
    wr_data = new[num_txns];

    `uvm_info("AHB_SEQ", $sformatf("Starting AHB sequence: %0d writes then %0d reads", num_txns, num_txns), UVM_MEDIUM)

    // ── PHASE 1 — num_txns WRITES ────────────────────────────────────────────
    // Distinct, word-aligned addresses below the register block (< 0x0F00),
    // each with a random 32-bit data value.
    for (i = 0; i < num_txns; i++) begin
      wr_addr[i] = 32'h0000_0100 + (i << 2);  // 0x100, 0x104, 0x108, ... distinct
      wr_data[i] = $urandom;

      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_wr_%0d", i));
      start_item(req);
      req.addr       = wr_addr[i];
      req.write      = 1'b1;
      req.wdata      = wr_data[i];
      req.trans_type = 2'b10;   // NONSEQ
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit)
      req.post_randomize();
      `uvm_info("AHB_SEQ", $sformatf("WRITE[%0d]: %s", i, req.convert2string()), UVM_HIGH)
      finish_item(req);
    end

    // ── PHASE 2 — num_txns READS of the SAME addresses ───────────────────────
    // The APB slave memory model returns the value stored by the matching
    // write, so each read should return wr_data[i] (not the 0xDEADBEEF default).
    for (i = 0; i < num_txns; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_rd_%0d", i));
      start_item(req);
      req.addr       = wr_addr[i];
      req.write      = 1'b0;
      req.wdata      = 32'h0;   // unused for reads
      req.trans_type = 2'b10;   // NONSEQ
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit)
      req.post_randomize();
      `uvm_info("AHB_SEQ", $sformatf("READ[%0d]: addr=0x%08h expect 0x%08h", i, wr_addr[i], wr_data[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("AHB_SEQ", $sformatf("AHB sequence complete: %0d writes + %0d reads", num_txns, num_txns), UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_bringup_seq