// =============================================================================
// FILE: sequences/ahb_mst_test_error_013_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_013
// DESCRIPTION: Stimulus for target_error_response_window_basic. Verifies that a
//              target error (PSLVERR) during the active phase produces HRESP=1
//              on the source side within the error response window, and that the
//              error is logged (sticky) and recoverable:
//                - configure CTRL=0x0000_0001 (ENABLE b0=1, TIMEOUT_EN=0),
//                  verify clean STATUS=0x0000_0001,
//                - good WRITE at 0x0000_1000 (HWDATA=0x0000_AAAA) completes OKAY
//                  with PSLVERR=0; confirm clean STATUS,
//                - inject target error: WRITE at 0x0000_2000 (HWDATA=0x0000_BEEF)
//                  with PSLVERR=1 at the target active phase — HRESP=1 within the
//                  error response window, STATUS.PSLVERR b5=1 set sticky,
//                - ERR_INT_EN=0 in this run, so STATUS.ERR_INT b7=0 but PSLVERR
//                  remains; expect STATUS=0x0000_0021 (PSLVERR=1, READY=1),
//                - read error log: ERROR_ADDR=0x0000_2000, ERROR_INFO captured
//                  (direction=write, coarse class=target-error),
//                - recovery: W1C bit 5 write STATUS=0x0000_0020 clears PSLVERR
//                  (STATUS=0x0000_0001),
//                - soft reset CTRL=0x0000_0003 (SOFT_RST b1=1 + ENABLE b0=1)
//                  fully clears ERROR_ADDR=0 / ERROR_INFO=0; SOFT_RST self-clears
//                  so CTRL reads back 0x0000_0001,
//                - re-enable CTRL=0x0000_0001,
//                - post-recovery good READ at 0x0000_1004 returns
//                  PRDATA=0x1234_5678 with HRESP=0 and a clean STATUS=0x0000_0001
//                  error log, proving data integrity and full recovery.
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
//   - XTP TEST_ERROR_013 steps 1-15 — configure CTRL=0x0000_0001, good write at
//     0x0000_1000, confirm clean STATUS, inject PSLVERR=1 on a WRITE at
//     0x0000_2000 -> HRESP=1 within the error response window, STATUS.PSLVERR
//     b5=1 sticky, ERR_INT disabled (STATUS=0x0000_0021), ERROR_ADDR=0x0000_2000,
//     ERROR_INFO direction=write, W1C clears PSLVERR, SOFT_RST clears error log,
//     re-enable, post-recovery good read at 0x0000_1004 returns 0x1234_5678 with
//     a clean log, proving data integrity.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PSLVERR
//       injection, error response window, sticky behavior, and error-log capture
//       are modelled in the APB slave / DUT; this sequence drives register and
//       data stimulus only, and the response/sticky/W1C/soft-reset checks live
//       in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_013_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_013_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good traffic completes OKAY. The injected write raises PSLVERR=1 at the
  // target active phase, which the DUT propagates to HRESP and captures sticky.
  localparam logic [31:0] ADDR_GOOD_WR   = 32'h0000_1000;  // good write
  localparam logic [31:0] DATA_GOOD_WR   = 32'h0000_AAAA;  // expected PWDATA
  localparam logic [31:0] ADDR_PSLVERR   = 32'h0000_2000;  // PSLVERR write injection
  localparam logic [31:0] DATA_PSLVERR   = 32'h0000_BEEF;  // injected write data
  localparam logic [31:0] ADDR_GOOD_RD   = 32'h0000_1004;  // post-recovery read
  localparam logic [31:0] DATA_GOOD_RD   = 32'h1234_5678;  // expected PRDATA / HRDATA

  // ── Control values ──────────────────────────────────────────────────────────
  // CTRL=0x0001: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=0 (interrupt disabled)
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0001; // enable, no err interrupt
  // CTRL=0x0003: ENABLE b0=1 + SOFT_RST b1=1 (recovery, clears debug regs)
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003; // SOFT_RST asserted

  // ── STATUS W1C value ──────────────────────────────────────────────────────
  localparam logic [31:0] STATUS_W1C_PSLVERR = 32'h0000_0020; // W1C PSLVERR b5

  function new(string name = "ahb_mst_test_error_013_seq");
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
    `uvm_info("ERR013_SEQ",
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
    `uvm_info("ERR013_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR013_SEQ",
      "Starting TEST_ERROR_013: target error response window basic (HRESP=1, log, recover)",
      UVM_MEDIUM)

    // ── Step 1: configure CTRL=0x0000_0001 (ENABLE=1, TIMEOUT_EN=0), verify ────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");        // expect 0x0000_0001

    // ── Step 2: good WRITE at 0x0000_1000 (PSLVERR=0) — completes OKAY ─────────
    do_write(ADDR_GOOD_WR, DATA_GOOD_WR, "good_wr");          // PWDATA=0x0000_AAAA

    // ── Step 3: read STATUS — confirm clean before injection (0x0000_0001) ─────
    do_read (REG_STATUS,     "status_clean");                // expect 0x0000_0001, PSLVERR=0

    // ── Step 4: inject target error — WRITE at 0x0000_2000 with PSLVERR=1 ──────
    // At the target active phase (PSEL=1, PENABLE=1) PSLVERR=1 fires.
    do_write(ADDR_PSLVERR, DATA_PSLVERR, "inject_pslverr");

    // ── Step 5: read STATUS — HRESP=1 observed within window, PSLVERR sticky ───
    do_read (REG_STATUS,     "status_pslverr");              // PSLVERR set sticky

    // ── Step 6: check aggregated interrupt (ERR_INT_EN=0) — ERR_INT=0 ──────────
    do_read (REG_STATUS,     "status_errint");               // ERR_INT=0, PSLVERR remains

    // ── Step 7: read error log type — STATUS=0x0000_0021 (PSLVERR=1, READY=1) ──
    do_read (REG_STATUS,     "status_errclass");             // expect 0x0000_0021

    // ── Step 8: read error info — ERROR_ADDR=0x2000, ERROR_INFO direction=write ─
    do_read (REG_ERROR_ADDR, "erraddr_pslverr");             // expect 0x0000_2000
    do_read (REG_ERROR_INFO, "errinfo_pslverr");             // direction=write, target-error

    // ── Step 9: clear sticky — W1C bit 5 write STATUS=0x0000_0020 ──────────────
    do_write(REG_STATUS, STATUS_W1C_PSLVERR, "w1c_pslverr");

    // ── Step 10: verify cleared — read STATUS (0x0000_0001) ────────────────────
    do_read (REG_STATUS,     "status_cleared");              // expect 0x0000_0001

    // ── Step 11: recovery — soft reset CTRL=0x0000_0003 (SOFT_RST=1, ENABLE=1) ─
    // SOFT_RST clears active state + sticky flags, ERROR_ADDR=0 / ERROR_INFO=0,
    // and self-clears (CTRL reads back 0x0000_0001).
    do_write(REG_CTRL,   CTRL_SOFT_RST, "ctrl_softrst");

    // ── Step 12: read error log after recovery — STATUS/ERR regs cleared ───────
    do_read (REG_STATUS,     "status_recov");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_recov");               // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");               // expect 0x0000_0000

    // ── Step 13: reconfigure device — re-enable CTRL=0x0000_0001 ───────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reenable");
    do_read (REG_STATUS,              "status_reenable");    // expect 0x0000_0001

    // ── Step 14: post-recovery good READ at 0x0000_1004 -> PRDATA=0x1234_5678 ──
    do_read (ADDR_GOOD_RD,   "good_rd");                     // expect HRDATA=0x1234_5678, HRESP=0

    // ── Step 15: PROVE — re-read error log: STATUS/ERR regs clean ──────────────
    do_read (REG_STATUS,     "status_final");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_final");               // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_final");               // expect 0x0000_0000

    `uvm_info("ERR013_SEQ", "TEST_ERROR_013 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_013_seq
