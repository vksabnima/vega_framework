// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_009_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_009
// DESCRIPTION: Stimulus for fsm_idle_to_setup_on_accepted_request.
//              Drives a single accepted source-side (AHB) request so the bridge
//              FSM leaves IDLE and enters SETUP on the first target-side cycle.
//              The transfer presents HSEL=1, HTRANS=NONSEQ (New),
//              HADDR=0x0000_1000. On the SETUP cycle the bridge must assert
//              PSEL=1 with PENABLE=0 and PADDR=0x0000_1000, holding PENABLE=0
//              for exactly one SETUP cycle (no premature ACTIVE entry).
//
//              Baseline (before the request): FSM in IDLE, PSEL=0, PENABLE=0.
//              After the accepted request: IDLE -> SETUP, PSEL=1, PENABLE=0,
//              PADDR=0x0000_1000 stable in SETUP.
//
//              Single word-aligned WRITE transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                HADDR=0x0000_1000
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_009 steps 1-4 — confirm idle baseline (PSEL=0,
//     PENABLE=0), present an accepted request, observe IDLE->SETUP with PSEL=1,
//     PENABLE=0, PADDR=0x0000_1000 held for exactly one SETUP cycle.
//
// NOTE: No .randomize() — fixed address per [TC1]. PSEL/PENABLE/PADDR sequencing
//       is produced by the bridge FSM and observed by the monitors; this
//       sequence only presents the accepted AHB request.
//
// CONFIDENCE: HIGH — single NONSEQ transfer exercising the IDLE->SETUP edge.
// =============================================================================

class ahb_mst_test_protocol_009_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_009_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_1000;

  function new(string name = "ahb_mst_test_protocol_009_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO009_SEQ",
      "Starting TEST_PROTOCOL_009: present one accepted AHB request (HSEL=1, HTRANS=NONSEQ, HADDR=0x0000_1000); bridge FSM must leave IDLE only on the accepted request and enter SETUP with PSEL=1, PENABLE=0, PADDR=0x0000_1000 held for exactly one SETUP cycle",
      UVM_MEDIUM)

    // ── Transfer — accepted NONSEQ WRITE request ─────────────────────────────
    // FSM baseline is IDLE (PSEL=0, PENABLE=0). Presenting this accepted request
    // drives IDLE -> SETUP: the bridge asserts PSEL=1 with PENABLE=0 and
    // PADDR=0x0000_1000 on the first target-side cycle, holding PENABLE=0 for
    // exactly one SETUP cycle before ACTIVE.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_009");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = 32'h0;       // data is irrelevant to the IDLE->SETUP edge
    req.trans_type = 2'b10;       // NONSEQ/New transfer (accepted request)
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO009_SEQ",
      $sformatf("REQUEST: HADDR=0x%08h (IDLE->SETUP: expect PSEL=1, PENABLE=0, PADDR=0x%08h for exactly one SETUP cycle)",
                TEST_ADDR, TEST_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO009_SEQ", "TEST_PROTOCOL_009 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_009_seq
