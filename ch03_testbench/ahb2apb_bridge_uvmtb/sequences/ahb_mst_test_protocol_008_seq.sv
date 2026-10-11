// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_008_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_008
// DESCRIPTION: Stimulus for wait_state_back_to_back_after_stall.
//              Drives two accepted source-side (AHB) write requests back-to-back
//              so the bridge translates each into a target-side (APB)
//              SETUP -> ACTIVE phase. The first transfer is stalled by the
//              target (PREADY=0) before completing (PREADY=1); the bridge must
//              hold HREADY_OUT=0 during the stall and release back-pressure
//              (HREADY_OUT=1) at completion. Only after the first transfer
//              completes is the second new request accepted, re-entering SETUP
//              (PSEL=1, PENABLE=0) then ACTIVE (PSEL=1, PENABLE=1) for the
//              second address.
//
//              Two single word-aligned WRITE transfers:
//                #1 HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                   HADDR=0x0000_4000, HWDATA=0x1111_2222
//                #2 HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                   HADDR=0x0000_4004, HWDATA=0x3333_4444
//
//              The bridge is expected to produce, per transfer:
//                CAPTURE: request accepted, HREADY_OUT=0
//                SETUP  : PSEL=1, PENABLE=0, PADDR=<addr>, PWDATA=<data>
//                ACTIVE : PSEL=1, PENABLE=1; while PREADY=0 the first transfer is
//                         held — HREADY_OUT=0
//                DONE   : with PREADY=1 the handshake completes; HREADY_OUT=1,
//                         HRESP=0; PENABLE deasserts. Idle at end: PSEL=0,
//                         PENABLE=0; STATUS.READY=1, BUSY=0.
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_008 steps 1-7 — drive a stalled write then, only after
//     it completes, a second new write, observing correct release of back-pressure
//     and correct SETUP(PENABLE=0) -> ACTIVE(PENABLE=1) sequencing per transfer.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. The PREADY stall timing
//       (PREADY=0 then PREADY=1) is supplied by the reactive APB slave sequence
//       (apb_slv_bringup_seq), not driven here.
//
// CONFIDENCE: HIGH — two NONSEQ writes exercising back-to-back-after-stall.
// =============================================================================

class ahb_mst_test_protocol_008_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_008_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR0  = 32'h0000_4000;
  localparam logic [31:0] TEST_WDATA0 = 32'h1111_2222;
  localparam logic [31:0] TEST_ADDR1  = 32'h0000_4004;
  localparam logic [31:0] TEST_WDATA1 = 32'h3333_4444;

  function new(string name = "ahb_mst_test_protocol_008_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO008_SEQ",
      "Starting TEST_PROTOCOL_008: drive a stalled write then a second new write; bridge must release back-pressure (HREADY_OUT 0->1) and accept the second transfer with correct SETUP(PENABLE=0)->ACTIVE(PENABLE=1) sequencing",
      UVM_MEDIUM)

    // ── Transfer #1 — stalled WRITE ──────────────────────────────────────────
    // The bridge captures HADDR/HWDATA and drives the APB SETUP phase
    // (PSEL=1, PENABLE=0, PADDR=0x0000_4000, PWDATA=0x1111_2222) then ACTIVE
    // (PSEL=1, PENABLE=1). While the target holds PREADY=0 the transfer is held
    // (HREADY_OUT=0). When the target asserts PREADY=1 the handshake completes:
    // HREADY_OUT=1, HRESP=0, PENABLE deasserts.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_wr0");
    start_item(req);
    req.addr       = TEST_ADDR0;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = TEST_WDATA0;
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO008_SEQ",
      $sformatf("WRITE#1: HADDR=0x%08h HWDATA=0x%08h (HREADY_OUT=0 during PREADY=0 stall; HREADY_OUT=1, HRESP=0 at PREADY=1 completion)",
                TEST_ADDR0, TEST_WDATA0), UVM_HIGH)
    finish_item(req);

    // ── Transfer #2 — new WRITE accepted only after #1 completes ──────────────
    // Back-pressure released (HREADY_OUT was 1) so the bridge accepts the new
    // request and re-enters SETUP (PSEL=1, PENABLE=0, PADDR=0x0000_4004,
    // PWDATA=0x3333_4444) then ACTIVE (PSEL=1, PENABLE=1), completing with
    // HREADY_OUT=1, HRESP=0; returning to idle (PSEL=0, PENABLE=0).
    req = ahb_mst_seq_item::type_id::create("ahb_proto_wr1");
    start_item(req);
    req.addr       = TEST_ADDR1;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = TEST_WDATA1;
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO008_SEQ",
      $sformatf("WRITE#2: HADDR=0x%08h HWDATA=0x%08h (accepted after #1 completes; SETUP PENABLE=0 -> ACTIVE PENABLE=1; HREADY_OUT=1, HRESP=0 at completion)",
                TEST_ADDR1, TEST_WDATA1), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO008_SEQ", "TEST_PROTOCOL_008 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_008_seq
