// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_010_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_010
// DESCRIPTION: Stimulus for fsm_setup_to_active_advance.
//              Drives a single accepted source-side (AHB) request so the bridge
//              FSM enters SETUP (PSEL=1, PENABLE=0, PADDR=0x0000_1000) and then
//              advances SETUP -> ACTIVE on the next rising edge, asserting
//              PENABLE=1 while PSEL stays continuously high and PADDR holds
//              stable at 0x0000_1000.
//
//              Phase sequencing produced by the bridge FSM:
//                T1 (SETUP) : PSEL=1, PENABLE=0, PADDR=0x0000_1000
//                T2 (edge)  : FSM advances SETUP -> ACTIVE
//                T3 (ACTIVE): PSEL=1, PENABLE=1, PADDR=0x0000_1000 unchanged
//              PSEL stays 1 across both cycles; PENABLE rises exactly one cycle
//              after PSEL.
//
//              Single word-aligned WRITE transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                HADDR=0x0000_1000
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_010 steps 1-4 — confirm SETUP (PSEL=1, PENABLE=0,
//     PADDR=0x0000_1000), allow the FSM to advance, observe ACTIVE with PSEL=1,
//     PENABLE=1, PADDR unchanged, and PSEL continuously high across both phases.
//
// NOTE: No .randomize() — fixed address per [TC1]. PSEL/PENABLE/PADDR sequencing
//       is produced by the bridge FSM and observed by the monitors; this
//       sequence only presents the accepted AHB request.
//
// CONFIDENCE: HIGH — single NONSEQ transfer exercising the SETUP->ACTIVE edge.
// =============================================================================

class ahb_mst_test_protocol_010_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_010_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_1000;

  function new(string name = "ahb_mst_test_protocol_010_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO010_SEQ",
      "Starting TEST_PROTOCOL_010: present one accepted AHB request (HSEL=1, HTRANS=NONSEQ, HADDR=0x0000_1000); bridge FSM must enter SETUP (PSEL=1, PENABLE=0) and advance SETUP->ACTIVE asserting PENABLE=1 one cycle later while PSEL stays continuously high and PADDR holds stable",
      UVM_MEDIUM)

    // ── Transfer — accepted NONSEQ WRITE request ─────────────────────────────
    // Presenting this accepted request drives the FSM into SETUP (PSEL=1,
    // PENABLE=0, PADDR=0x0000_1000). On the next rising edge the FSM advances
    // SETUP -> ACTIVE: PENABLE asserts (=1) exactly one cycle after PSEL, PSEL
    // remains 1 across both cycles, and PADDR holds at 0x0000_1000.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_010");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = 32'h0;       // data is irrelevant to the SETUP->ACTIVE edge
    req.trans_type = 2'b10;       // NONSEQ/New transfer (accepted request)
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO010_SEQ",
      $sformatf("REQUEST: HADDR=0x%08h (SETUP: PSEL=1, PENABLE=0; ACTIVE one cycle later: PSEL=1, PENABLE=1, PADDR=0x%08h stable)",
                TEST_ADDR, TEST_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO010_SEQ", "TEST_PROTOCOL_010 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_010_seq
