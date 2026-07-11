// =============================================================================
// FILE: sequences/ahb_mst_test_error_011_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_011
// DESCRIPTION: Stimulus for target_error_sticky_persistence_no_clear. Verifies
//              the sticky behavior of STATUS.PSLVERR after a target error — the
//              flag persists across subsequent good (non-error) traffic and is
//              only removed by W1C / soft reset:
//                - configure CTRL=0x0000_0001 (ENABLE b0=1), verify clean
//                  STATUS=0x0000_0001,
//                - good WRITE at 0x0000_6000 (HWDATA=0xA5A5_0001) completes OKAY
//                  with PSLVERR=0; confirm clean STATUS,
//                - inject target error: WRITE at 0x0000_6010 (HWDATA=0xA5A5_0002)
//                  with PSLVERR=1 at the target active phase — HRESP=1,
//                  STATUS.PSLVERR b5=1 set sticky, error capture triggered,
//                - ERR_INT_EN=0 in this run, so STATUS.ERR_INT b7=0 but PSLVERR
//                  remains; expect STATUS=0x0000_0021 (PSLVERR=1, READY=1),
//                - read error log: ERROR_ADDR=0x0000_6010, ERROR_INFO captured
//                  (direction=write, coarse class=target-error),
//                - send a subsequent GOOD WRITE at 0x0000_6020 (HWDATA=
//                  0xA5A5_0003) WITHOUT clearing — completes HRESP=0 but the
//                  sticky STATUS.PSLVERR must NOT auto-clear (stays 0x0000_0021),
//                - recovery: W1C bit 5 write STATUS=0x0000_0020 clears PSLVERR
//                  (STATUS=0x0000_0001); ERROR_ADDR/ERROR_INFO retain last
//                  capture (RO, not cleared by STATUS W1C),
//                - soft reset CTRL=0x0000_0003 (SOFT_RST b1=1 + ENABLE b0=1)
//                  fully clears ERROR_ADDR=0 / ERROR_INFO=0; SOFT_RST self-clears
//                  so CTRL reads back 0x0000_0001,
//                - post-recovery good WRITE at 0x0000_7000 (HWDATA=0xC0DE_0004)
//                  completes OKAY, and a read-back at 0x0000_7000 returns
//                  0xC0DE_0004 with a clean STATUS=0x0000_0001 error log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3, ...)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_011 steps 1-15 — configure CTRL=0x0000_0001, good write at
//     0x0000_6000, confirm clean STATUS, inject PSLVERR=1 on a WRITE at
//     0x0000_6010 -> HRESP=1, STATUS.PSLVERR b5=1 sticky, ERR_INT disabled
//     (STATUS=0x0000_0021), ERROR_ADDR=0x0000_6010, ERROR_INFO direction=write,
//     good write at 0x0000_6020 must NOT auto-clear sticky, W1C clears PSLVERR,
//     SOFT_RST clears error log, post-recovery write+read-back at 0x0000_7000
//     (0xC0DE_0004) proves data integrity with a clean log.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PSLVERR
//       injection, sticky behavior, and error-log capture are modelled in the
//       APB slave / DUT; this sequence drives register and data stimulus only,
//       and the sticky / W1C / soft-reset checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_011_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_011_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good writes complete OKAY. The injected write raises PSLVERR=1 at the target
  // active phase, which the DUT propagates to HRESP and captures sticky.
  localparam logic [31:0] ADDR_GOOD_WR1  = 32'h0000_6000;  // good write
  localparam logic [31:0] DATA_GOOD_WR1  = 32'hA5A5_0001;  // expected PWDATA
  localparam logic [31:0] ADDR_PSLVERR   = 32'h0000_6010;  // PSLVERR write injection
  localparam logic [31:0] DATA_PSLVERR   = 32'hA5A5_0002;  // injected write data
  localparam logic [31:0] ADDR_GOOD_WR2  = 32'h0000_6020;  // good write, no clear
  localparam logic [31:0] DATA_GOOD_WR2  = 32'hA5A5_0003;  // expected PWDATA
  localparam logic [31:0] ADDR_GOOD_WR3  = 32'h0000_7000;  // post-recovery write
  localparam logic [31:0] DATA_GOOD_WR3  = 32'hC0DE_0004;  // expected PWDATA / read-back

  // ── Control values ──────────────────────────────────────────────────────────
  // CTRL=0x0001: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=0 (interrupt disabled)
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0001; // enable, no err interrupt
  // CTRL=0x0003: ENABLE b0=1 + SOFT_RST b1=1 (recovery, clears debug regs)
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003; // SOFT_RST asserted

  // ── STATUS W1C value ──────────────────────────────────────────────────────
  localparam logic [31:0] STATUS_W1C_PSLVERR = 32'h0000_0020; // W1C PSLVERR b5

  function new(string name = "ahb_mst_test_error_011_seq");
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
    `uvm_info("ERR011_SEQ",
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
    `uvm_info("ERR011_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR011_SEQ",
      "Starting TEST_ERROR_011: target error sticky persistence (no clear by good traffic)",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_0001 (ENABLE=1), verify ─────────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");        // expect 0x0000_0001

    // ── T2: good WRITE at 0x0000_6000 (PSLVERR=0) — completes OKAY ─────────────
    do_write(ADDR_GOOD_WR1, DATA_GOOD_WR1, "good_wr1");      // PWDATA=0xA5A5_0001

    // ── T3: read STATUS — confirm clean before injection (0x0000_0001) ────────
    do_read (REG_STATUS,     "status_clean");                // expect 0x0000_0001, PSLVERR=0

    // ── T4: inject target error — WRITE at 0x0000_6010 with PSLVERR=1 ─────────
    // At the target active phase PSLVERR=1 fires; error capture triggered.
    do_write(ADDR_PSLVERR, DATA_PSLVERR, "inject_pslverr");

    // ── T5: read STATUS — expect PSLVERR b5=1 (sticky), HRESP=1 observed ──────
    do_read (REG_STATUS,     "status_pslverr");              // PSLVERR set sticky

    // ── T6: check aggregated interrupt (ERR_INT_EN=0) — ERR_INT=0, PSLVERR=1 ──
    do_read (REG_STATUS,     "status_errint");               // ERR_INT=0, PSLVERR remains

    // ── T7: read error log type — STATUS=0x0000_0021 (PSLVERR=1, READY=1) ─────
    do_read (REG_STATUS,     "status_errclass");             // expect 0x0000_0021

    // ── T8: read error log — ERROR_ADDR=0x6010, ERROR_INFO direction=write ────
    do_read (REG_ERROR_ADDR, "erraddr_pslverr");             // expect 0x0000_6010
    do_read (REG_ERROR_INFO, "errinfo_pslverr");             // direction=write, target-error

    // ── T9: subsequent GOOD WRITE at 0x0000_6020 WITHOUT clearing ─────────────
    // Good transfer completes HRESP=0, but sticky PSLVERR must NOT auto-clear.
    do_write(ADDR_GOOD_WR2, DATA_GOOD_WR2, "good_wr2_noclear"); // PWDATA=0xA5A5_0003

    // ── T10: read STATUS — verify sticky persistence (0x0000_0021 retained) ───
    do_read (REG_STATUS,     "status_sticky");               // expect 0x0000_0021, PSLVERR still=1

    // ── T11: recovery — W1C bit 5 write STATUS=0x0000_0020 to clear PSLVERR ───
    do_write(REG_STATUS, STATUS_W1C_PSLVERR, "w1c_pslverr");

    // ── T12: read error log after recovery — STATUS clean, ERR regs retained ──
    do_read (REG_STATUS,     "status_recov");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_retained");            // retains 0x0000_6010 (RO, not W1C-cleared)
    do_read (REG_ERROR_INFO, "errinfo_retained");            // retains last-captured info

    // ── T13: soft reset — CTRL=0x0000_0003 (SOFT_RST=1, ENABLE=1), re-read ────
    // SOFT_RST clears ERROR_ADDR=0 / ERROR_INFO=0 and self-clears (CTRL=0x0001).
    do_write(REG_CTRL,   CTRL_SOFT_RST, "ctrl_softrst");
    do_read (REG_CTRL,                  "ctrl_after_rst");   // expect 0x0000_0001

    // ── T14: post-recovery good WRITE at 0x0000_7000 -> PWDATA=0xC0DE_0004 ─────
    do_write(ADDR_GOOD_WR3, DATA_GOOD_WR3, "good_wr3");      // PWDATA=0xC0DE_0004

    // ── T15: PROVE — read-back at 0x0000_7000 returns 0xC0DE_0004, clean log ──
    do_read (ADDR_GOOD_WR3,  "readback_wr3");                // expect 0xC0DE_0004
    do_read (REG_STATUS,     "status_final");                // expect 0x0000_0001, no sticky errors

    `uvm_info("ERR011_SEQ", "TEST_ERROR_011 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_011_seq
