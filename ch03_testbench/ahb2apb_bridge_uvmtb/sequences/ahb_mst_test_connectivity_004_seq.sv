// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_004
// DESCRIPTION: Stimulus for source_clock_connectivity.
//              Drives a single source-side AHB WRITE and relies on the
//              synchronous driver/monitor to advance the bridge FSM exactly one
//              phase per HCLK rising edge:
//                IDLE  -> (T1 edge) source capture: registers HADDR=0x0000_3000
//                SETUP -> (T2 edge) target setup:   PSEL=1, PADDR=0x0000_3000
//                ACTIVE-> (T3 edge) target active:  PENABLE=1
//              No phase progression occurs while HCLK is static; every FSM
//              transition aligns to exactly one HCLK rising edge, proving HCLK
//              connectivity.
//
//              One single word-aligned transfer:
//                WRITE HADDR=0x0000_3000, HWRITE=1, HTRANS=2'b10 (NONSEQ),
//                      HSIZE=3'b010 (word), HBURST=3'b000 (SINGLE)
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_004 steps 1-5 — drive HSEL=1, HTRANS=2'b10,
//     HWRITE=1, HADDR=0x0000_3000, HREADY_IN=1; observe one-edge-per-phase
//     IDLE->SETUP->ACTIVE progression synchronous to HCLK.
//
// NOTE: No .randomize() — fixed address/data per [TC1]. Clock-edge alignment is
//       enforced by the synchronous AHB driver/monitor, not by the sequence.
//
// CONFIDENCE: HIGH — straightforward single source-side write stimulus.
// =============================================================================

class ahb_mst_test_connectivity_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_004_seq)

  function new(string name = "ahb_mst_test_connectivity_004_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] test_addr = 32'h0000_3000;
    logic [31:0] test_data = 32'h1234_5678;

    `uvm_info("CONN004_SEQ",
      "Starting TEST_CONNECTIVITY_004: single source-side write, HCLK-synchronous FSM progression",
      UVM_MEDIUM)

    // ── T1..T3 — WRITE to 0x0000_3000 ──────────────────────────────────────
    // The synchronous driver applies the address/control phase on an HCLK
    // rising edge (source capture, FLOW-1). The bridge then advances one phase
    // per subsequent HCLK edge: SETUP (PSEL=1, PADDR=0x0000_3000) then ACTIVE
    // (PENABLE=1). No progression occurs without a clock edge.
    req = ahb_mst_seq_item::type_id::create("ahb_conn004_wr");
    start_item(req);
    req.addr       = test_addr;
    req.write      = 1'b1;    // Write — step drives HWRITE=1
    req.wdata      = test_data;
    req.trans_type = 2'b10;   // NONSEQ — new transfer (HTRANS=2'b10)
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("CONN004_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h (expect synchronous IDLE->SETUP->ACTIVE, one phase per HCLK edge)",
                test_addr, test_data), UVM_HIGH)
    finish_item(req);

    `uvm_info("CONN004_SEQ", "TEST_CONNECTIVITY_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_004_seq
