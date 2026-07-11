// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_007_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_007
// DESCRIPTION: Stimulus for wait_state_read_data_after_completion.
//              Drives one accepted source-side (AHB) read request so the bridge
//              translates it into a target-side (APB) SETUP -> ACTIVE phase.
//              While the target holds PREADY=0 across wait cycles the bridge must
//              keep HREADY_OUT deasserted and must NOT commit read data to HRDATA.
//              Only when the target asserts PREADY=1 (with PRDATA=0xCAFE_F00D at
//              completion) does the transfer complete: HREADY_OUT=1,
//              HRDATA=0xCAFE_F00D (the value sampled at completion, not the
//              stalled 0xDEAD_BEEF), HRESP=0; STATUS.READY=1, BUSY=0.
//
//              Single word-aligned READ transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=0, HSIZE=word,
//                HADDR=0x0000_3004
//
//              The bridge is expected to produce:
//                CAPTURE: request accepted, HREADY_OUT=0
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_3004, PWRITE=0
//                ACTIVE : PSEL=1, PENABLE=1; across every PREADY=0 wait cycle the
//                         transfer is held — HREADY_OUT=0, read data NOT yet
//                         committed to HRDATA
//                DONE   : with PREADY=1 / PRDATA=0xCAFE_F00D the handshake
//                         completes; HREADY_OUT=1, HRDATA=0xCAFE_F00D, HRESP=0;
//                         HRDATA held stable for the source read; STATUS.READY=1,
//                         BUSY=0
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_007 steps 1-6 — drive a NONSEQ read and observe that
//     HRDATA is not presented as valid until PREADY=1 completes the access, and
//     that HREADY_OUT gating matches (deasserted for every PREADY=0 cycle).
//
// NOTE: No .randomize() — fixed address per [TC1]. The PREADY stall timing and
//       the returned PRDATA (value at completion) are supplied by the reactive
//       APB slave sequence (apb_slv_bringup_seq), not driven here.
//
// CONFIDENCE: HIGH — single NONSEQ read exercising read-data-after-completion.
// =============================================================================

class ahb_mst_test_protocol_007_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_007_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR  = 32'h0000_3004;
  localparam logic [31:0] EXP_RDATA  = 32'hCAFE_F00D;

  function new(string name = "ahb_mst_test_protocol_007_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO007_SEQ",
      "Starting TEST_PROTOCOL_007: drive one NONSEQ read; HRDATA must not be valid until PREADY=1 completes the access, HREADY_OUT deasserted for every PREADY=0 cycle",
      UVM_MEDIUM)

    // Single source-side READ request. The bridge captures HADDR and drives the
    // APB SETUP phase (PSEL=1, PENABLE=0, PADDR=0x0000_3004, PWRITE=0) then the
    // ACTIVE phase (PSEL=1, PENABLE=1). While the target holds PREADY=0 the
    // transfer is held active (HREADY_OUT=0) and read data is NOT committed to
    // HRDATA. When the target asserts PREADY=1 with PRDATA=0xCAFE_F00D the
    // handshake completes and the bridge drives HREADY_OUT=1, HRDATA=0xCAFE_F00D,
    // HRESP=0, returning to idle.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_rd");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b0;        // HWRITE=0 — read request
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO007_SEQ",
      $sformatf("READ: HADDR=0x%08h (HREADY_OUT=0 while PREADY=0; HREADY_OUT=1 with HRDATA=0x%08h only at/after PREADY=1 completion)",
                TEST_ADDR, EXP_RDATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO007_SEQ", "TEST_PROTOCOL_007 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_007_seq
