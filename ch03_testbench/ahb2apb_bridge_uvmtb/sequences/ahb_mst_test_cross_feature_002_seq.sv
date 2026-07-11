// =============================================================================
// FILE: sequences/ahb_mst_test_cross_feature_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CROSS_FEATURE_002
// DESCRIPTION: Stimulus for target_error_during_back_pressure. Drives an AHB
//              read that the APB peripheral stalls (PREADY=0) for several
//              cycles before finally completing on the SAME edge it asserts the
//              error (PREADY rises with PSLVERR=1). This exposes error-latching
//              faults in the stall-then-error race that single-feature error
//              tests miss. After the faulting read, the sequence reads back
//              STATUS / ERROR_ADDR / ERROR_INFO to confirm the sticky error
//              context was captured.
//
//              All stimulus is issued as raw AHB transactions. Register
//              accesses target the control/status block at PADDR 0xF00..0xF0C;
//              data-plane traffic targets the legal region
//              0x0000_0000-0x0000_FFFF. The multi-cycle stall and the
//              coincident PSLVERR are produced by the APB slave / tb harness;
//              the scoreboard validates the error propagation (HRESP=1) and the
//              latched sticky state.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ...)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ERR_INT, PSLVERR sticky, ...)
//   ERROR_ADDR = 0xF08  (captured faulting address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_002 steps T1-T9 — read transfer captured, target
//     setup/active under three-cycle back-pressure, PREADY rising coincident
//     with PSLVERR=1, error propagated to source (HRESP=1), STATUS/ERROR_ADDR/
//     ERROR_INFO read-back confirming sticky PSLVERR + ERR_INT and the faulting
//     address 0x0000_3000.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_cross_feature_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_cross_feature_002_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane address ──────────────────────────────────────────────────────
  localparam logic [31:0] ADDR_FAULT     = 32'h0000_3000;  // faulting read addr

  function new(string name = "ahb_mst_test_cross_feature_002_seq");
    super.new(name);
  endfunction : new

  // ── Helper: drive a single word WRITE transaction ─────────────────────────
  task automatic do_write(input logic [31:0] addr, input logic [31:0] data,
                          input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_wr_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b1;
    req.wdata      = data;
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("XFEAT002_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // ── Helper: drive a single word READ transaction ──────────────────────────
  task automatic do_read(input logic [31:0] addr, input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_rd_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b0;
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("XFEAT002_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("XFEAT002_SEQ",
      "Starting TEST_CROSS_FEATURE_002: target error during back-pressure",
      UVM_MEDIUM)

    // ── T1-T5: launch the read that the peripheral stalls (PREADY=0) for ──────
    // several cycles before completing. Source captures the read transfer
    // (FLOW-1), target setup -> active phase asserts (FLOW-2), and the bridge
    // holds with HREADY_OUT=0 while the back-pressure persists (FLOW-4). The
    // stall and the coincident PSLVERR on the releasing edge are produced by
    // the APB slave / tb harness; the AHB master remains parked on this read.
    //
    // ── T6-T7: on the edge the peripheral releases back-pressure (PREADY=1) ───
    // it also drives PSLVERR=1 with PRDATA=0x0000_0000. The bridge must complete
    // the transfer and propagate HRESP=1 (ERROR) to the source coincident with
    // completion — the error must not be lost despite the preceding stall.
    do_read(ADDR_FAULT, "fault_read");

    // ── T8: read back STATUS — expect sticky PSLVERR=1 and ERR_INT=1 latched, ──
    // with BUSY=0 and READY=1 now that the faulting transfer has completed.
    do_read(REG_STATUS,     "status_posterror");

    // ── T9: read back ERROR_ADDR and ERROR_INFO to confirm captured context. ──
    // Expect ERROR_ADDR=0x0000_3000 (faulting address) and ERROR_INFO encoding
    // the read direction + target-error class.
    do_read(REG_ERROR_ADDR, "erraddr_posterror");
    do_read(REG_ERROR_INFO, "errinfo_posterror");

    `uvm_info("XFEAT002_SEQ", "TEST_CROSS_FEATURE_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_cross_feature_002_seq
