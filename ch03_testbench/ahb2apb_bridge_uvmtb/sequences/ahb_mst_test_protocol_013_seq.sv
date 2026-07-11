// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_013_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_013
// DESCRIPTION: Stimulus for fsm_full_cycle_setup_stall_active_complete.
//              Drives a single accepted source-side (AHB) request so the bridge
//              FSM walks the complete state-machine sequence with correct
//              PSEL/PENABLE/PREADY timing across all phases:
//                IDLE -> SETUP -> ACTIVE -> ACTIVE(stall) -> IDLE
//
//              Phase sequencing produced by the bridge FSM and reactive APB
//              slave (the slave inserts a PREADY=0 wait cycle):
//                T1 (IDLE)  : accepted request presented (HSEL=1, HTRANS=NONSEQ,
//                             HADDR=0x0000_2000); IDLE->SETUP
//                T2 (SETUP) : PSEL=1, PENABLE=0, PADDR=0x0000_2000
//                T3 (rising): SETUP->ACTIVE; PSEL=1, PENABLE=1
//                T4 (ACTIVE, PREADY=0) : self-loop held; PSEL=1, PENABLE=1 stable
//                T5 (rising, PREADY=1) : handshake completes; ACTIVE->IDLE
//                T6 (IDLE)  : PSEL=0, PENABLE=0
//              A STATUS read at 0xF04 then returns 0x0000_0001 (READY=1, BUSY=0),
//              proving the full cycle returned cleanly to IDLE.
//
//              Transfers:
//                1. WRITE — HTRANS=NONSEQ, HWRITE=1, HSIZE=word, HADDR=0x0000_2000
//                2. READ  — HTRANS=NONSEQ, HWRITE=0, HSIZE=word, HADDR=0x0000_0F04
//                           (STATUS register read-back)
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_013 steps 1-6 — confirm the state order
//     IDLE->SETUP->ACTIVE->ACTIVE(stall)->IDLE with PENABLE asserting exactly one
//     cycle after PSEL, the self-loop holding while PREADY=0, PSEL/PENABLE
//     deasserting on PREADY=1, and STATUS READY=1/BUSY=0 after completion.
//
// NOTE: No .randomize() — fixed addresses per [TC1]. The PSEL/PENABLE/PREADY
//       phase timing, the SETUP->ACTIVE->ACTIVE(stall)->IDLE walk, and the
//       wait-state self-loop are produced by the bridge FSM and reactive APB
//       slave and observed by the monitors; this sequence only presents the
//       accepted AHB requests. Register access goes through the AHB master as a
//       raw transaction to PADDR 0xF04.
//
// CONFIDENCE: HIGH — single NONSEQ write plus a STATUS read-back.
// =============================================================================

class ahb_mst_test_protocol_013_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_013_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR   = 32'h0000_2000;  // full-cycle transfer address
  localparam logic [31:0] STATUS_ADDR = 32'h0000_0F04;  // STATUS register (READY/BUSY)

  function new(string name = "ahb_mst_test_protocol_013_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO013_SEQ",
      "Starting TEST_PROTOCOL_013: present one accepted AHB request (HSEL=1, HTRANS=NONSEQ, HADDR=0x0000_2000); bridge FSM walks IDLE->SETUP->ACTIVE->ACTIVE(stall)->IDLE with PSEL=1/PENABLE=0 in SETUP, PSEL=1/PENABLE=1 in ACTIVE, a held self-loop while PREADY=0, and PSEL=0/PENABLE=0 back in IDLE on PREADY=1; a STATUS read at 0xF04 then confirms READY=1, BUSY=0",
      UVM_MEDIUM)

    // ── Transfer 1 — accepted NONSEQ WRITE request (full FSM cycle) ───────────
    // Presenting this accepted request drives the FSM IDLE->SETUP (PSEL=1,
    // PENABLE=0, PADDR=0x0000_2000), then SETUP->ACTIVE (PSEL=1, PENABLE=1). The
    // reactive APB slave holds PREADY=0 for a wait cycle (ACTIVE self-loop, signals
    // stable), then asserts PREADY=1 to complete the handshake, returning the FSM
    // ACTIVE->IDLE with PSEL=0, PENABLE=0.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_013_full_cycle");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = 32'h0;       // data is irrelevant to the FSM phase walk
    req.trans_type = 2'b10;       // NONSEQ/New transfer (accepted request)
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO013_SEQ",
      $sformatf("REQUEST: HADDR=0x%08h (IDLE->SETUP: PSEL=1/PENABLE=0; SETUP->ACTIVE: PSEL=1/PENABLE=1; stall while PREADY=0; on PREADY=1 ACTIVE->IDLE, PSEL=0/PENABLE=0)",
                TEST_ADDR), UVM_HIGH)
    finish_item(req);

    // ── Transfer 2 — STATUS register read-back (0xF04) ───────────────────────
    // After the full cycle the FSM must be cleanly back in IDLE. Read the STATUS
    // register to confirm READY bit[0]=1 and BUSY bit[1]=0 (STATUS=0x0000_0001),
    // proving the full cycle returned to IDLE.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_013_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;        // HWRITE=0 — read request (STATUS read-back)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO013_SEQ",
      $sformatf("STATUS READ: HADDR=0x%08h (expect READY bit[0]=1, BUSY bit[1]=0 -> STATUS=0x0000_0001)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO013_SEQ", "TEST_PROTOCOL_013 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_013_seq
