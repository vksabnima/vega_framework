// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_011_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_011
// DESCRIPTION: Stimulus for fsm_active_stall_self_loop.
//              Drives a single accepted source-side (AHB) request so the bridge
//              FSM enters ACTIVE (PSEL=1, PENABLE=1, PADDR=0x0000_1000). While
//              the APB target holds PREADY=0 (wait states), the FSM must remain
//              in ACTIVE (self-loop): PSEL=1, PENABLE=1, and PADDR=0x0000_1000
//              stay bit-stable for every cycle PREADY=0, with no transition.
//
//              Phase sequencing produced by the bridge FSM under target stall:
//                T1 (ACTIVE, PREADY=0) : PSEL=1, PENABLE=1, PADDR=0x0000_1000
//                T2 (ACTIVE, PREADY=0) : ACTIVE held — signals unchanged
//                T3 (ACTIVE, PREADY=0) : ACTIVE held — signals stable, no transition
//              The ACTIVE self-loop persists every cycle PREADY=0; PSEL, PENABLE,
//              and PADDR are bit-stable across the stall window.
//
//              Single word-aligned WRITE transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                HADDR=0x0000_1000
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_011 steps 1-4 — confirm ACTIVE self-loop on PREADY=0,
//     with PSEL=1, PENABLE=1 held stable and PADDR=0x0000_1000 unchanged across
//     the stall cycles T1-T3 (no signal change during wait states).
//
// NOTE: No .randomize() — fixed address per [TC1]. PSEL/PENABLE/PADDR sequencing
//       and the PREADY=0 wait states are produced by the bridge FSM and reactive
//       APB slave and observed by the monitors; this sequence only presents the
//       accepted AHB request that drives the FSM into ACTIVE.
//
// CONFIDENCE: HIGH — single NONSEQ transfer exercising the ACTIVE stall self-loop.
// =============================================================================

class ahb_mst_test_protocol_011_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_011_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_1000;

  function new(string name = "ahb_mst_test_protocol_011_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO011_SEQ",
      "Starting TEST_PROTOCOL_011: present one accepted AHB request (HSEL=1, HTRANS=NONSEQ, HADDR=0x0000_1000); bridge FSM enters ACTIVE (PSEL=1, PENABLE=1) and must self-loop in ACTIVE for every cycle PREADY=0, holding PSEL=1, PENABLE=1, and PADDR=0x0000_1000 bit-stable with no transition during the wait states",
      UVM_MEDIUM)

    // ── Transfer — accepted NONSEQ WRITE request ─────────────────────────────
    // Presenting this accepted request drives the FSM into ACTIVE (PSEL=1,
    // PENABLE=1, PADDR=0x0000_1000). While the APB target holds PREADY=0 the
    // FSM self-loops in ACTIVE: PSEL, PENABLE, and PADDR remain bit-stable for
    // every stall cycle, and the FSM does not transition until PREADY=1.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_011");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = 32'h0;       // data is irrelevant to the ACTIVE stall self-loop
    req.trans_type = 2'b10;       // NONSEQ/New transfer (accepted request)
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO011_SEQ",
      $sformatf("REQUEST: HADDR=0x%08h (ACTIVE: PSEL=1, PENABLE=1; self-loop while PREADY=0 — PADDR=0x%08h held stable, no transition)",
                TEST_ADDR, TEST_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO011_SEQ", "TEST_PROTOCOL_011 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_011_seq
