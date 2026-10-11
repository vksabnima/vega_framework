// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_003
// DESCRIPTION: Stimulus for wait_state_signal_stability_during_target_stall.
//              Drives one accepted source-side (AHB) read request so the bridge
//              translates it into a target-side (APB) SETUP -> ACTIVE phase. The
//              target then stalls (PREADY=0) for several cycles; during the
//              stall the ACTIVE-phase signals must remain stable and the source
//              completion (HREADY_OUT) must stay low. When the target finally
//              asserts PREADY=1 with PRDATA=0x1234_5678 / PSLVERR=0 the transfer
//              completes and HRDATA returns to the source unchanged.
//
//              Single word-aligned READ transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=0, HSIZE=word,
//                HADDR=0x0000_0200
//
//              The bridge is expected to produce:
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_0200, HREADY_OUT=0
//                ACTIVE : PSEL=1, PENABLE=1; while PREADY=0 the phase is held —
//                         PSEL/PENABLE/PADDR stable, HREADY_OUT=0 for every
//                         wait cycle
//                DONE   : on PREADY=1 -> PSEL=0, PENABLE=0, HREADY_OUT=1,
//                         HRESP=0, HRDATA=0x1234_5678 (== captured PRDATA)
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_003 steps 1-5 — drive a NONSEQ read and observe the
//     held ACTIVE-phase signals across the target stall and the eventual
//     HRDATA return when PREADY asserts.
//
// NOTE: No .randomize() — fixed address per [TC1]. The target stall (PREADY
//       timing) and PRDATA are supplied by the reactive APB slave sequence
//       (apb_slv_bringup_seq), not driven here.
//
// CONFIDENCE: HIGH — single NONSEQ read exercising wait-state signal stability.
// =============================================================================

class ahb_mst_test_protocol_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_003_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_0200;
  localparam logic [31:0] EXP_RDATA = 32'h1234_5678;

  function new(string name = "ahb_mst_test_protocol_003_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO003_SEQ",
      "Starting TEST_PROTOCOL_003: drive one NONSEQ read to exercise APB wait-state signal stability during target stall",
      UVM_MEDIUM)

    // Single source-side READ request. The bridge captures HADDR and drives the
    // APB SETUP phase (PSEL=1, PENABLE=0) then the ACTIVE phase (PSEL=1,
    // PENABLE=1). The target stalls (PREADY=0); during the stall the ACTIVE-phase
    // signals must remain stable and HREADY_OUT must stay 0. When the target
    // asserts PREADY=1 the returned PRDATA propagates back as HRDATA.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_rd");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b0;    // HWRITE=0 — read request
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ/New transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO003_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect PADDR=0x%08h held across stall, HREADY_OUT=0 during wait, HRDATA=0x%08h on completion)",
                TEST_ADDR, TEST_ADDR, EXP_RDATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO003_SEQ", "TEST_PROTOCOL_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_003_seq
