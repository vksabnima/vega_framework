// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_006
// DESCRIPTION: Stimulus for wait_state_signal_stability_multi_wait.
//              Drives one accepted source-side (AHB) read request so the bridge
//              translates it into a target-side (APB) SETUP -> ACTIVE phase.
//              Across SEVERAL consecutive PREADY=0 wait cycles the bridge must
//              hold PSEL=1, PENABLE=1, PADDR=0x0000_2000 and PWRITE=0 stable and
//              keep HREADY_OUT deasserted. Only when the target asserts PREADY=1
//              (with PRDATA=0x1234_5678) does the transfer complete: HREADY_OUT=1,
//              HRDATA=0x1234_5678, HRESP=0.
//
//              Single word-aligned READ transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=0, HSIZE=word,
//                HADDR=0x0000_2000
//
//              The bridge is expected to produce:
//                CAPTURE: request accepted, BUSY toward active, HREADY_OUT=0
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_2000, PWRITE=0
//                ACTIVE : PSEL=1, PENABLE=1; across every PREADY=0 wait cycle the
//                         transfer is held — HREADY_OUT=0, PADDR/PWRITE unchanged
//                DONE   : with PREADY=1 / PRDATA=0x1234_5678 the handshake
//                         completes; HREADY_OUT=1, HRDATA=0x1234_5678, HRESP=0;
//                         PSEL=0, PENABLE=0; STATUS.READY=1, BUSY=0
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_006 steps 1-8 — drive a NONSEQ read and observe that
//     multiple PREADY=0 wait cycles hold PSEL/PENABLE/PADDR/PWRITE stable and
//     keep HREADY_OUT deasserted until PREADY=1 returns PRDATA.
//
// NOTE: No .randomize() — fixed address per [TC1]. The multi-cycle PREADY stall
//       timing and the returned PRDATA are supplied by the reactive APB slave
//       sequence (apb_slv_bringup_seq), not driven here.
//
// CONFIDENCE: HIGH — single NONSEQ read exercising multi-wait signal stability.
// =============================================================================

class ahb_mst_test_protocol_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_006_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR  = 32'h0000_2000;
  localparam logic [31:0] EXP_RDATA  = 32'h1234_5678;

  function new(string name = "ahb_mst_test_protocol_006_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO006_SEQ",
      "Starting TEST_PROTOCOL_006: drive one NONSEQ read; several PREADY=0 wait cycles must hold PSEL/PENABLE/PADDR/PWRITE stable and keep HREADY_OUT deasserted until PREADY=1",
      UVM_MEDIUM)

    // Single source-side READ request. The bridge captures HADDR and drives the
    // APB SETUP phase (PSEL=1, PENABLE=0, PADDR=0x0000_2000, PWRITE=0) then the
    // ACTIVE phase (PSEL=1, PENABLE=1). While the target holds PREADY=0 across
    // multiple wait cycles the transfer is held active (HREADY_OUT=0,
    // PADDR/PWRITE unchanged). When the target asserts PREADY=1 with
    // PRDATA=0x1234_5678 the handshake completes and the bridge drives
    // HREADY_OUT=1, HRDATA=0x1234_5678, HRESP=0, returning to idle.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_rd");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b0;        // HWRITE=0 — read request
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // NONSEQ/New transfer
    req.burst      = 3'b000;      // SINGLE
    req.size       = 3'b010;      // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO006_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect PADDR=0x%08h/PWRITE=0 held across PREADY=0 wait cycles, HREADY_OUT=1 with HRDATA=0x%08h only after PREADY=1)",
                TEST_ADDR, TEST_ADDR, EXP_RDATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO006_SEQ", "TEST_PROTOCOL_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_006_seq
