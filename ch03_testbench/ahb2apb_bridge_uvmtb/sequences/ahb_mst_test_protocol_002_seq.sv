// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_002
// DESCRIPTION: Stimulus for target_active_completion_handshake.
//              Drives one accepted source-side (AHB) read request so the bridge
//              translates it into a target-side (APB) SETUP -> ACTIVE phase and
//              then completes when the target asserts PREADY. The APB slave
//              returns PRDATA=0xA5A5_A5A5; on completion the bridge deasserts
//              PSEL/PENABLE, releases the source completion (HREADY_OUT=1) and
//              returns HRDATA=0xA5A5_A5A5 with HRESP=0.
//
//              Single word-aligned READ transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=0, HSIZE=word,
//                HADDR=0x0000_0100
//
//              The bridge is expected to produce:
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_0100, HREADY_OUT=0
//                ACTIVE : PSEL=1, PENABLE=1; with PREADY=1 the transfer is
//                         eligible to complete this cycle
//                DONE   : PSEL=0, PENABLE=0, HREADY_OUT=1, HRESP=0,
//                         HRDATA=0xA5A5_A5A5 (== captured PRDATA)
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_002 steps 1-4 — drive a NONSEQ read and observe the
//     APB ACTIVE-phase completion handshake (PREADY) and HRDATA return.
//
// NOTE: No .randomize() — fixed address per [TC1]. PRDATA is supplied by the
//       reactive APB slave sequence (apb_slv_bringup_seq), not driven here.
//
// CONFIDENCE: HIGH — single NONSEQ read exercising ACTIVE-phase completion.
// =============================================================================

class ahb_mst_test_protocol_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_002_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_0100;
  localparam logic [31:0] EXP_RDATA = 32'hA5A5_A5A5;

  function new(string name = "ahb_mst_test_protocol_002_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO002_SEQ",
      "Starting TEST_PROTOCOL_002: drive one NONSEQ read to exercise APB ACTIVE-phase completion",
      UVM_MEDIUM)

    // Single source-side READ request. The bridge captures HADDR and drives the
    // APB SETUP phase (PSEL=1, PENABLE=0) then the ACTIVE phase (PSEL=1,
    // PENABLE=1). When the target asserts PREADY the transfer completes and the
    // returned PRDATA propagates back to the source as HRDATA.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_rd");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b0;    // HWRITE=0 — read request
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ/New transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO002_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect PADDR=0x%08h, ACTIVE completion, HRDATA=0x%08h)",
                TEST_ADDR, TEST_ADDR, EXP_RDATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO002_SEQ", "TEST_PROTOCOL_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_002_seq
