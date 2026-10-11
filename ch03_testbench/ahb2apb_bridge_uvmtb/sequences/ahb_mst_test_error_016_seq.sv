// =============================================================================
// FILE: sequences/ahb_mst_test_error_016_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_016
// DESCRIPTION: Stimulus for back_to_back_error_then_normal_no_stale_state.
//              Verifies a target error transfer immediately followed (after a
//              full clear) by a normal transfer does not produce a stale HRESP
//              or stale sticky bits — proving error response window isolation:
//                - configure CTRL=0x0000_0001 (ENABLE b0=1), verify clean
//                  STATUS=0x0000_0001,
//                - good WRITE at 0x0000_4000 (HWDATA=0x0000_9999) completes OKAY
//                  (PSEL=1, PENABLE=1 active; HREADY_OUT=1, HRESP=0),
//                - read STATUS — confirm clean (all sticky error bits 0),
//                - inject target error: READ at 0x0000_4100 with PSLVERR=1,
//                  PREADY=1, PRDATA=0xFFFF_FFFF sampled at the T3 active phase —
//                  HRESP=1 asserted within the error response window (T4..T6),
//                  HREADY_OUT=1 at window close; HRDATA not consumed (error path),
//                - read STATUS — PSLVERR b5 set sticky, STATUS=0x0000_0021,
//                  ERR_INT b7=0 (ERR_INT_EN disabled),
//                - read error info: ERROR_ADDR=0x0000_4100, ERROR_INFO direction=
//                  read / target-error class,
//                - W1C PSLVERR b5: write STATUS=0x0000_0020 -> STATUS=0x0000_0001,
//                - recovery: soft reset CTRL=0x0000_0003 (ENABLE + SOFT_RST b1)
//                  clears active state + sticky flags + error log (PSEL=0,
//                  PENABLE=0, HRESP=0, HREADY_OUT=1); STATUS=0x0000_0001,
//                  ERROR_ADDR=0, ERROR_INFO=0,
//                - reconfigure CTRL=0x0000_0001 (clean baseline),
//                - post-recovery good READ at the SAME address class 0x0000_4100
//                  returns PRDATA=0x1357_9BDF with HRESP=0 (NO stale error) and a
//                  clean STATUS=0x0000_0001 / ERROR_ADDR=0x0000_0000 error log,
//                  proving no stale-state leakage and full data integrity.
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
//   - XTP TEST_ERROR_016 steps 1-15 — configure CTRL=0x0000_0001, good write at
//     0x0000_4000, confirm clean STATUS, inject PSLVERR=1 on a READ at
//     0x0000_4100 -> HRESP=1 only within its error response window, STATUS=
//     0x0000_0021, ERROR_ADDR=0x0000_4100, W1C bit5 (STATUS=0x0000_0020) then
//     SOFT_RST CTRL=0x0000_0003 fully clears state, reconfigure CTRL=0x0000_0001,
//     post-recovery good read at the SAME address 0x0000_4100 returns
//     0x1357_9BDF with HRESP=0 and a clean error log.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PSLVERR
//       injection, HRESP timing, error response window, sticky behavior, W1C and
//       error-log capture are modelled in the APB slave / DUT; this sequence
//       drives register and data stimulus only, and the response/timing/sticky/
//       W1C/soft-reset/no-stale-state checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_016_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_016_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good traffic completes OKAY. The injected read raises PSLVERR=1 at the
  // target active phase (T3), which the DUT propagates to HRESP within the
  // error response window (T4..T6) while capturing the error log sticky. The
  // post-recovery read targets the SAME address class to prove no stale state.
  localparam logic [31:0] ADDR_GOOD_WR   = 32'h0000_4000;  // good write
  localparam logic [31:0] DATA_GOOD_WR   = 32'h0000_9999;  // expected PWDATA
  localparam logic [31:0] ADDR_PSLVERR   = 32'h0000_4100;  // PSLVERR read injection
  localparam logic [31:0] DATA_GOOD_RD   = 32'h1357_9BDF;  // expected PRDATA / HRDATA post-recovery

  // ── Control values ──────────────────────────────────────────────────────────
  // CTRL=0x0001: ENABLE b0=1, ERR_INT_EN b3=0 (interrupt disabled — clean baseline)
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0001; // enable, no err interrupt
  // CTRL=0x0003: ENABLE b0=1 + SOFT_RST b1=1 (recovery, config preserved)
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003; // SOFT_RST + ENABLE

  // ── STATUS W1C value — clear PSLVERR b5 (READY b0 left set) ─────────────────
  localparam logic [31:0] STATUS_W1C_PSLVERR = 32'h0000_0020; // W1C PSLVERR b5

  function new(string name = "ahb_mst_test_error_016_seq");
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
    `uvm_info("ERR016_SEQ",
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
    `uvm_info("ERR016_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR016_SEQ",
      "Starting TEST_ERROR_016: back-to-back error then normal — no stale HRESP / sticky state",
      UVM_MEDIUM)

    // ── Step 1: configure CTRL=0x0000_0001 (ENABLE=1), verify clean ────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");        // expect 0x0000_0001

    // ── Step 2: good WRITE at 0x0000_4000 (PSLVERR=0) — completes OKAY ─────────
    // PSEL=1, PENABLE=1 active; HREADY_OUT=1 at completion, HRESP=0.
    do_write(ADDR_GOOD_WR, DATA_GOOD_WR, "good_wr");          // PWDATA=0x0000_9999

    // ── Step 3: read STATUS — confirm clean (all sticky error bits 0) ──────────
    do_read (REG_STATUS,     "status_clean");                // expect 0x0000_0001

    // ── Step 4: inject target error — READ at 0x0000_4100 with PSLVERR=1 ───────
    // PSEL=1,PENABLE=1 at T3; PSLVERR=1,PREADY=1,PRDATA=0xFFFF_FFFF sampled at the
    // active phase. HRDATA not consumed (error path); HRESP=1 in window T4..T6.
    do_read (ADDR_PSLVERR,   "inject_pslverr");

    // ── Step 5: verify error detected — HRESP=1 within window, HREADY_OUT=1 close
    do_read (REG_STATUS,     "status_pslverr");              // PSLVERR set sticky

    // ── Step 6: check interrupt — ERR_INT_EN=0, STATUS.ERR_INT b7=0 ────────────
    // ── Step 7: read error log — STATUS=0x0000_0021 (PSLVERR b5=1, READY b0=1) ─
    do_read (REG_STATUS,     "status_errlog");               // expect 0x0000_0021

    // ── Step 8: read error info — ERROR_ADDR=0x4100, ERROR_INFO direction=read ─
    do_read (REG_ERROR_ADDR, "erraddr_pslverr");             // expect 0x0000_4100
    do_read (REG_ERROR_INFO, "errinfo_pslverr");             // direction=read, target-error

    // ── Step 9: clear sticky — W1C bit 5 write STATUS=0x0000_0020 ──────────────
    do_write(REG_STATUS, STATUS_W1C_PSLVERR, "w1c_pslverr");

    // ── Step 10: verify cleared — read STATUS (0x0000_0001) ────────────────────
    do_read (REG_STATUS,     "status_cleared");              // expect 0x0000_0001

    // ── Step 11: recovery — soft reset CTRL=0x0000_0003 (SOFT_RST + ENABLE) ─────
    // Active state cleared: PSEL=0, PENABLE=0, HRESP=0, HREADY_OUT=1.
    do_write(REG_CTRL,   CTRL_SOFT_RST, "ctrl_softrst");

    // ── Step 12: read error log after recovery — STATUS/ERR regs clear ─────────
    do_read (REG_STATUS,     "status_recov");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_recov");               // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");               // expect 0x0000_0000

    // ── Step 13: reconfigure — re-enable CTRL=0x0000_0001 (clean baseline) ─────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reenable");
    do_read (REG_STATUS,              "status_reenable");    // expect 0x0000_0001

    // ── Step 14: post-recovery good READ at SAME address 0x0000_4100 ───────────
    // CRITICAL: HRDATA=0x1357_9BDF, HRESP=0 (no stale error), HREADY_OUT=1.
    do_read (ADDR_PSLVERR,   "good_rd_same_addr");           // expect HRDATA=0x1357_9BDF, HRESP=0

    // ── Step 15: PROVE — re-read error log: STATUS/ERR_ADDR clean (no stale) ────
    do_read (REG_STATUS,     "status_final");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_final");               // expect 0x0000_0000

    `uvm_info("ERR016_SEQ", "TEST_ERROR_016 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_016_seq
