// =============================================================================
// FILE: sequences/ahb_mst_test_bringup_init_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_BRINGUP_INIT_002
// DESCRIPTION: Stimulus for pclk_hclk_edge_alignment_check
//              (single_clock_domain_bringup). With PCLK tied to the HCLK source,
//              drives a single AHB transfer (HSEL=0x1 implied by an active
//              transfer, HTRANS=NONSEQ(0b10), HADDR=0x0000_1000) on an HCLK
//              rising edge. Because PCLK==HCLK there is no CDC latency: the
//              source-side request is captured on the same edge seen by the
//              PCLK domain and the peripheral-side PSEL asserts deterministically
//              relative to that shared clock edge.
//
// DERIVED FROM:
//   - XTP TEST_BRINGUP_INIT_002 step 3 — drive a single transfer
//     HSEL=0x1, HTRANS=0b10 (new), HADDR=0x0000_1000 on an HCLK edge.
//
// NOTE: No .randomize() — fixed address per [TC1]. Single transfer only.
//
// CONFIDENCE: HIGH — straightforward single-transfer stimulus.
// =============================================================================

class ahb_mst_test_bringup_init_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_bringup_init_002_seq)

  // Edge-alignment probe transfer address (XTP step 3).
  localparam logic [31:0] EDGE_ALIGN_ADDR = 32'h0000_1000;

  function new(string name = "ahb_mst_test_bringup_init_002_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("INIT002_SEQ",
      "Starting TEST_BRINGUP_INIT_002: single transfer HADDR=0x0000_1000 in single clock domain",
      UVM_MEDIUM)

    // Single AHB transfer driven on an HCLK rising edge. HSEL=0x1 is implied by
    // an active (NONSEQ) transfer targeting the APB-mapped region; PCLK==HCLK so
    // the request and PSEL assertion track the same shared edge (no CDC latency).
    req = ahb_mst_seq_item::type_id::create("ahb_edge_align");
    start_item(req);
    req.addr       = EDGE_ALIGN_ADDR;
    req.write      = 1'b1;    // Write transfer to drive a deterministic PSEL/setup
    req.wdata      = 32'h0000_0000;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("INIT002_SEQ",
      $sformatf("DRIVE edge-align transfer: addr=0x%08h HTRANS=0b%02b", req.addr, req.trans_type),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("INIT002_SEQ", "TEST_BRINGUP_INIT_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_bringup_init_002_seq
