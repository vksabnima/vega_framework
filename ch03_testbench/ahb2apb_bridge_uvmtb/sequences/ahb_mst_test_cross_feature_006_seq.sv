// =============================================================================
// FILE: sequences/ahb_mst_test_cross_feature_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CROSS_FEATURE_006
// DESCRIPTION: Stimulus for back_to_back_with_error_recovery. Exposes error-
//              isolation faults in a back-to-back stream where one beat errors
//              (PSLVERR=1 on beat 2) and the following beat must complete
//              cleanly. Sequence handling and error features alone do not cover
//              whether an error on beat N leaks into beat N+1 — the bug only
//              appears when a continued stream straddles an errored beat.
//
//              All stimulus is issued as raw AHB transactions. Three streamed
//              word writes advance the address 0x0400 -> 0x0404 -> 0x0408
//              (beat 1 NONSEQ, beats 2/3 SEQ). The peripheral is armed to assert
//              PSLVERR=1 on the second beat only; the back-pressure / PREADY /
//              PSLVERR timing is produced by the AHB master driver / APB slave
//              harness. After the stream the sequence reads STATUS, ERROR_ADDR
//              and ERROR_INFO to confirm the sticky error context latched from
//              the faulting beat, then performs a verification read-back of beat
//              3 (0x0408) expecting PRDATA=0x3333_3333. The scoreboard validates
//              that beats 1 and 3 complete cleanly (HRESP=0), that beat 2 reports
//              the error (HRESP=1), and that no transaction is lost (VG1-VG6).
//
// REGISTER MAP (raw AHB accesses to the register block):
//   STATUS     = 0xF04  (READY b0, BUSY b1, sticky PSLVERR / ERR_INT bits, ...)
//   ERROR_ADDR = 0xF08  (address of most-recent faulting beat)
//   ERROR_INFO = 0xF0C  (direction + target-error class of last error)
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_006 steps T1-T8 — drive three streamed word writes
//     (0x0400/0x0404/0x0408, data 0x1111_1111/0x2222_2222/0x3333_3333) where
//     beat 2 takes a target error (PSLVERR=1); read STATUS/ERROR_ADDR/ERROR_INFO
//     to confirm the sticky context (ERROR_ADDR=0x0000_0404); read back 0x0408
//     expecting 0x3333_3333 / HRESP=0 to prove error isolation and recovery.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — the
//       STATUS / ERROR_ADDR / ERROR_INFO accesses are raw AHB transactions to
//       0xF04 / 0xF08 / 0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_cross_feature_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_cross_feature_006_seq)

  // ── Register block offsets (raw AHB access to the control/status block) ─────
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane stream addresses / payloads ─────────────────────────────────
  localparam logic [31:0] ADDR_B1 = 32'h0000_0400;  // beat 1 (NONSEQ)
  localparam logic [31:0] ADDR_B2 = 32'h0000_0404;  // beat 2 (SEQ) — errors
  localparam logic [31:0] ADDR_B3 = 32'h0000_0408;  // beat 3 (SEQ) — recovers
  localparam logic [31:0] DATA_B1 = 32'h1111_1111;
  localparam logic [31:0] DATA_B2 = 32'h2222_2222;
  localparam logic [31:0] DATA_B3 = 32'h3333_3333;

  function new(string name = "ahb_mst_test_cross_feature_006_seq");
    super.new(name);
  endfunction : new

  // ── Helper: drive a single word WRITE transaction ──────────────────────────
  // trans is the HTRANS value: 2'b10 NONSEQ (first beat) or 2'b11 SEQ (stream).
  task automatic do_write(input logic [31:0] addr,
                          input logic [31:0] data,
                          input logic [1:0]  trans,
                          input string       tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_wr_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b1;
    req.wdata      = data;
    req.trans_type = trans;
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    req.trans_type = trans;   // restore stream HTRANS after post_randomize default
    `uvm_info("XFEAT006_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h trans=0b%02b", tag, addr, data, trans),
      UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // ── Helper: drive a single word READ transaction ───────────────────────────
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
    `uvm_info("XFEAT006_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("XFEAT006_SEQ",
      "Starting TEST_CROSS_FEATURE_006: back-to-back stream with error recovery",
      UVM_MEDIUM)

    // ── T1-T5: streamed writes 0x0400 -> 0x0404 -> 0x0408 ────────────────────
    // Beat 1 (NONSEQ) is captured and forwarded. Beat 2 (SEQ) continues the
    // stream and takes a target error (PSLVERR=1 -> HRESP=1); the sticky
    // PSLVERR / ERR_INT bits latch and ERROR_ADDR captures 0x0000_0404. Beat 3
    // (SEQ) proceeds with the peripheral healthy and must NOT be aborted or
    // corrupted by the prior beat-2 error — it completes with HRESP=0 and
    // delivers PWDATA=0x3333_3333. The PREADY / PSLVERR timing per beat is
    // produced by the driver / APB slave harness.
    do_write(ADDR_B1, DATA_B1, 2'b10, "beat1_nseq");  // T1-T2
    do_write(ADDR_B2, DATA_B2, 2'b11, "beat2_seq");   // T2-T3 — errors
    do_write(ADDR_B3, DATA_B3, 2'b11, "beat3_seq");   // T4-T5 — recovers

    // ── T6: read back STATUS — sticky error bits persist from beat 2 ─────────
    // Expect sticky PSLVERR=1 and ERR_INT=1 still set, BUSY=0, READY=1.
    do_read(REG_STATUS, "status_after");

    // ── T7: read ERROR_ADDR / ERROR_INFO — captured faulting-beat context ────
    // Expect ERROR_ADDR=0x0000_0404 (beat 2, most-recent error); ERROR_INFO
    // encodes write direction + target-error class.
    do_read(REG_ERROR_ADDR, "error_addr");
    do_read(REG_ERROR_INFO, "error_info");

    // ── T8: verification read-back of beat 3 data ────────────────────────────
    // Expect HRDATA=0x3333_3333 / HRESP=0, proving beat-3 data integrity after
    // the intervening beat-2 error (error isolation + recovery).
    do_read(ADDR_B3, "readback_beat3");

    `uvm_info("XFEAT006_SEQ", "TEST_CROSS_FEATURE_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_cross_feature_006_seq
