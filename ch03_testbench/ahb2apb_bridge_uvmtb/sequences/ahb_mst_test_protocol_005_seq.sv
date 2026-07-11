// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_005
// DESCRIPTION: Stimulus for wait_state_basic_delayed_completion.
//              Drives one accepted source-side (AHB) write request so the bridge
//              translates it into a target-side (APB) SETUP -> ACTIVE phase. A
//              single target stall (PREADY=0) must hold PENABLE asserted and
//              delay HREADY_OUT until PREADY=1. The reactive APB slave models the
//              stall (holds PREADY low for the wait state, then asserts PREADY=1);
//              only on that completion cycle does the bridge complete the transfer
//              with HREADY_OUT=1, HRESP=0.
//
//              Single word-aligned WRITE transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                HADDR=0x0000_1000, HWDATA=0x0000_DA7A
//
//              The bridge is expected to produce:
//                CAPTURE: request accepted, BUSY toward active, HREADY_OUT=0
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_1000, PWRITE=1,
//                         PWDATA=0x0000_DA7A
//                ACTIVE : PSEL=1, PENABLE=1; while PREADY=0 the transfer is held —
//                         HREADY_OUT=0, PADDR/PWDATA unchanged
//                DONE   : with PREADY=1 the handshake completes; HREADY_OUT=1,
//                         HRESP=0; PSEL=0, PENABLE=0; STATUS.READY=1
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_005 steps 1-6 — drive a NONSEQ write and observe that a
//     single PREADY=0 stall holds PENABLE/PSEL stable and delays HREADY_OUT
//     until PREADY=1.
//
// NOTE: No .randomize() — fixed address/data per [TC1]. The PREADY stall timing
//       is supplied by the reactive APB slave sequence (apb_slv_bringup_seq),
//       not driven here.
//
// CONFIDENCE: HIGH — single NONSEQ write exercising basic wait-state completion.
// =============================================================================

class ahb_mst_test_protocol_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_005_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR  = 32'h0000_1000;
  localparam logic [31:0] TEST_WDATA = 32'h0000_DA7A;

  function new(string name = "ahb_mst_test_protocol_005_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO005_SEQ",
      "Starting TEST_PROTOCOL_005: drive one NONSEQ write; a single PREADY=0 stall must hold PENABLE and delay HREADY_OUT until PREADY=1",
      UVM_MEDIUM)

    // Single source-side WRITE request. The bridge captures HADDR/HWDATA and
    // drives the APB SETUP phase (PSEL=1, PENABLE=0) then the ACTIVE phase
    // (PSEL=1, PENABLE=1). While the target holds PREADY=0 the transfer is held
    // active (HREADY_OUT=0, PADDR/PWDATA unchanged). When the target asserts
    // PREADY=1 the handshake completes and the bridge drives HREADY_OUT=1,
    // HRESP=0, returning to idle.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_wr");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;        // HWRITE=1 — write request
    req.wdata      = TEST_WDATA;  // HWDATA driven on the source side
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO005_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h, PENABLE held during PREADY=0 stall, HREADY_OUT=1 only after PREADY=1)",
                TEST_ADDR, TEST_WDATA, TEST_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO005_SEQ", "TEST_PROTOCOL_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_005_seq
