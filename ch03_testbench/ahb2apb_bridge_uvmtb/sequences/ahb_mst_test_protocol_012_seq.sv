// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_012_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_012
// DESCRIPTION: Stimulus for fsm_active_to_idle_completion.
//              Drives a single accepted source-side (AHB) request so the bridge
//              FSM enters ACTIVE (PSEL=1, PENABLE=1, PADDR=0x0000_1000). When the
//              APB target completes the handshake (PREADY=1, PRDATA=0x0000_ABCD
//              captured), the FSM must transition ACTIVE->IDLE and deassert
//              PSEL/PENABLE. A follow-up STATUS register read confirms the clean
//              return to IDLE (READY=1, BUSY=0).
//
//              Phase sequencing produced by the bridge FSM:
//                T1 (ACTIVE, PREADY=0) : PSEL=1, PENABLE=1, PADDR=0x0000_1000
//                T2 (rising edge, PREADY=1) : handshake completes; PRDATA=0xABCD
//                                              captured; FSM ACTIVE->IDLE
//                T3 (IDLE)             : PSEL=0, PENABLE=0
//              A STATUS read at 0xF04 then returns 0x0000_0001 (READY=1, BUSY=0).
//
//              Transfers:
//                1. WRITE — HTRANS=NONSEQ, HWRITE=1, HSIZE=word, HADDR=0x0000_1000
//                2. READ  — HTRANS=NONSEQ, HWRITE=0, HSIZE=word, HADDR=0x0000_0F04
//                           (STATUS register read-back)
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_012 steps 1-4 — confirm FSM returns ACTIVE->IDLE on
//     PREADY=1, PSEL=0/PENABLE=0 in IDLE, PRDATA=0x0000_ABCD captured before
//     deassertion, and STATUS READY=1/BUSY=0 after completion.
//
// NOTE: No .randomize() — fixed addresses per [TC1]. The PSEL/PENABLE sequencing,
//       PREADY handshake completion, PRDATA capture, and ACTIVE->IDLE transition
//       are produced by the bridge FSM and reactive APB slave and observed by the
//       monitors; this sequence only presents the accepted AHB requests. Register
//       access goes through the AHB master as a raw transaction to PADDR 0xF04.
//
// CONFIDENCE: HIGH — single NONSEQ write plus a STATUS read-back.
// =============================================================================

class ahb_mst_test_protocol_012_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_012_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR   = 32'h0000_1000;  // ACTIVE transfer address
  localparam logic [31:0] STATUS_ADDR = 32'h0000_0F04;  // STATUS register (READY/BUSY)

  function new(string name = "ahb_mst_test_protocol_012_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO012_SEQ",
      "Starting TEST_PROTOCOL_012: present one accepted AHB request (HSEL=1, HTRANS=NONSEQ, HADDR=0x0000_1000); bridge FSM enters ACTIVE (PSEL=1, PENABLE=1) and on PREADY=1 must complete the handshake (PRDATA=0x0000_ABCD captured), transition ACTIVE->IDLE, and deassert PSEL/PENABLE; a STATUS read at 0xF04 then confirms READY=1, BUSY=0",
      UVM_MEDIUM)

    // ── Transfer 1 — accepted NONSEQ WRITE request ───────────────────────────
    // Presenting this accepted request drives the FSM into ACTIVE (PSEL=1,
    // PENABLE=1, PADDR=0x0000_1000). When the APB target asserts PREADY=1 the
    // handshake completes (PRDATA=0x0000_ABCD captured by the monitor) and the
    // FSM transitions ACTIVE->IDLE, deasserting PSEL/PENABLE.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_012_active");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = 32'h0;       // data is irrelevant to the ACTIVE->IDLE completion
    req.trans_type = 2'b10;       // NONSEQ/New transfer (accepted request)
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO012_SEQ",
      $sformatf("REQUEST: HADDR=0x%08h (ACTIVE: PSEL=1, PENABLE=1; on PREADY=1 capture PRDATA=0x0000_ABCD, complete handshake, ACTIVE->IDLE, PSEL=0/PENABLE=0)",
                TEST_ADDR), UVM_HIGH)
    finish_item(req);

    // ── Transfer 2 — STATUS register read-back (0xF04) ───────────────────────
    // After the handshake completes the FSM must be cleanly back in IDLE. Read
    // the STATUS register to confirm READY bit[0]=1 and BUSY bit[1]=0
    // (STATUS=0x0000_0001), proving the clean return to IDLE.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_012_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;        // HWRITE=0 — read request (STATUS read-back)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO012_SEQ",
      $sformatf("STATUS READ: HADDR=0x%08h (expect READY bit[0]=1, BUSY bit[1]=0 -> STATUS=0x0000_0001)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO012_SEQ", "TEST_PROTOCOL_012 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_012_seq
