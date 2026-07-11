// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_004
// DESCRIPTION: Stimulus for read_data_returned_only_after_target_completion.
//              Drives one accepted source-side (AHB) read request so the bridge
//              translates it into a target-side (APB) SETUP -> ACTIVE phase. The
//              read data must NOT be presented to the source until the target
//              completes (PREADY=1) in the ACTIVE phase. The reactive APB slave
//              holds PREADY low (stall) then asserts PREADY=1 with
//              PRDATA=0xDEAD_BEEF; only on that completion cycle does the bridge
//              return HRDATA to the source with HREADY_OUT=1, HRESP=0.
//
//              Single word-aligned READ transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=0, HSIZE=word,
//                HADDR=0x0000_0400
//
//              The bridge is expected to produce:
//                CAPTURE: request accepted, PSEL=0, PENABLE=0, HREADY_OUT=1
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_0400, HREADY_OUT=0
//                ACTIVE : PSEL=1, PENABLE=1; while PREADY=0 the read is held —
//                         HRDATA not valid, HREADY_OUT=0
//                DONE   : with PREADY=1 the bridge samples PRDATA; PSEL=0,
//                         PENABLE=0, HREADY_OUT=1, HRESP=0,
//                         HRDATA=0xDEAD_BEEF (== captured PRDATA)
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_004 steps 1-6 — drive a NONSEQ read and observe that the
//     read data is returned to the source only after the target completes
//     (PREADY=1) in the ACTIVE phase.
//
// NOTE: No .randomize() — fixed address per [TC1]. PRDATA is supplied by the
//       reactive APB slave sequence (apb_slv_bringup_seq), not driven here.
//
// CONFIDENCE: HIGH — single NONSEQ read exercising completion-gated read return.
// =============================================================================

class ahb_mst_test_protocol_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_004_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_0400;
  localparam logic [31:0] EXP_RDATA = 32'hDEAD_BEEF;

  function new(string name = "ahb_mst_test_protocol_004_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO004_SEQ",
      "Starting TEST_PROTOCOL_004: drive one NONSEQ read; read data must return only after target completion",
      UVM_MEDIUM)

    // Single source-side READ request. The bridge captures HADDR and drives the
    // APB SETUP phase (PSEL=1, PENABLE=0) then the ACTIVE phase (PSEL=1,
    // PENABLE=1). While the target holds PREADY=0 the read is stalled and HRDATA
    // is not presented to the source. When the target asserts PREADY=1 the bridge
    // samples PRDATA and returns it to the source as HRDATA with HREADY_OUT=1.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_rd");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b0;    // HWRITE=0 — read request
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ/New transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO004_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect PADDR=0x%08h, completion-gated, HRDATA=0x%08h after PREADY=1)",
                TEST_ADDR, TEST_ADDR, EXP_RDATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO004_SEQ", "TEST_PROTOCOL_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_004_seq
