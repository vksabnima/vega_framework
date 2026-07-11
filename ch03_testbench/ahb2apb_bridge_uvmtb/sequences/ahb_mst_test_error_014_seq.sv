// =============================================================================
// FILE: sequences/ahb_mst_test_error_014_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_014
// DESCRIPTION: Stimulus for error_response_two_cycle_window_hresp_timing.
//              Verifies the precise cycle timing of HRESP assertion relative to
//              PSLVERR sampling and the error response window before HREADY_OUT
//              completes:
//                - configure CTRL=0x0000_0001 (ENABLE b0=1), verify clean
//                  STATUS=0x0000_0001,
//                - good WRITE at 0x0000_3000 (HWDATA=0x0000_0F0F) completes OKAY
//                  (PSEL setup at T2, PENABLE active at T3, HREADY_OUT=1, HRESP=0),
//                - read STATUS — confirm clean (no sticky error bits),
//                - inject target error: WRITE at 0x0000_3100 (HWDATA=0x0000_DEAD)
//                  with PSLVERR=1, PREADY=1 sampled at the T3 active phase
//                  (PSEL=1, PENABLE=1) — HRESP=1 asserted at T4 held through the
//                  error response window (T5..T6) with HREADY_OUT gated low until
//                  window close,
//                - enable interrupt CTRL=0x0000_0009 (ENABLE + ERR_INT_EN b3) then
//                  re-inject — STATUS.ERR_INT b7 set sticky,
//                - read error log: STATUS=0x0000_00A1 (PSLVERR b5=1, ERR_INT b7=1,
//                  READY b0=1), ERROR_ADDR=0x0000_3100, ERROR_INFO direction=write,
//                - W1C bits 7 and 5: write STATUS=0x0000_00A0 clears ERR_INT and
//                  PSLVERR (STATUS=0x0000_0001),
//                - recovery: soft reset CTRL=0x0000_000B (ENABLE + ERR_INT_EN +
//                  SOFT_RST b1) clears active state + sticky flags + error log;
//                  config preserved so STATUS=0x0000_0009, ERROR_ADDR=0,
//                  ERROR_INFO=0,
//                - reconfigure CTRL=0x0000_0001 (disable interrupt for a clean
//                  baseline),
//                - post-recovery good READ at 0x0000_3104 returns
//                  PRDATA=0xCAFE_0001 with HRESP=0 and a clean STATUS=0x0000_0001
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
//   - XTP TEST_ERROR_014 steps 1-15 — configure CTRL=0x0000_0001, good write at
//     0x0000_3000, confirm clean STATUS, inject PSLVERR=1 on a WRITE at
//     0x0000_3100 -> HRESP=1 at T4 held through the error response window with
//     HREADY_OUT gated low, enable ERR_INT_EN and re-inject -> STATUS.ERR_INT
//     sticky, STATUS=0x0000_00A1, ERROR_ADDR=0x0000_3100, W1C bits 5+7
//     (STATUS=0x0000_00A0), SOFT_RST CTRL=0x0000_000B clears log preserving
//     config (STATUS=0x0000_0009), reconfigure CTRL=0x0000_0001, post-recovery
//     good read at 0x0000_3104 returns 0xCAFE_0001 with a clean log.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PSLVERR
//       injection, HRESP timing, error response window, sticky behavior, and
//       error-log capture are modelled in the APB slave / DUT; this sequence
//       drives register and data stimulus only, and the response/timing/sticky/
//       W1C/soft-reset checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_014_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_014_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good traffic completes OKAY. The injected write raises PSLVERR=1 at the
  // target active phase (T3), which the DUT propagates to HRESP at T4 and holds
  // through the error response window while capturing the error log sticky.
  localparam logic [31:0] ADDR_GOOD_WR   = 32'h0000_3000;  // good write
  localparam logic [31:0] DATA_GOOD_WR   = 32'h0000_0F0F;  // expected PWDATA
  localparam logic [31:0] ADDR_PSLVERR   = 32'h0000_3100;  // PSLVERR write injection
  localparam logic [31:0] DATA_PSLVERR   = 32'h0000_DEAD;  // injected write data
  localparam logic [31:0] ADDR_GOOD_RD   = 32'h0000_3104;  // post-recovery read
  localparam logic [31:0] DATA_GOOD_RD   = 32'hCAFE_0001;  // expected PRDATA / HRDATA

  // ── Control values ──────────────────────────────────────────────────────────
  // CTRL=0x0001: ENABLE b0=1, ERR_INT_EN b3=0 (interrupt disabled — clean baseline)
  localparam logic [31:0] CTRL_ENABLE        = 32'h0000_0001; // enable, no err interrupt
  // CTRL=0x0009: ENABLE b0=1 + ERR_INT_EN b3=1 (aggregated interrupt enabled)
  localparam logic [31:0] CTRL_ENABLE_ERRINT = 32'h0000_0009; // enable + ERR_INT_EN
  // CTRL=0x000B: ENABLE b0=1 + SOFT_RST b1=1 + ERR_INT_EN b3=1 (recovery)
  localparam logic [31:0] CTRL_SOFT_RST      = 32'h0000_000B; // SOFT_RST + config preserved

  // ── STATUS W1C value — clear ERR_INT b7 and PSLVERR b5 ─────────────────────
  localparam logic [31:0] STATUS_W1C_ERRINT  = 32'h0000_00A0; // W1C ERR_INT b7 + PSLVERR b5

  function new(string name = "ahb_mst_test_error_014_seq");
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
    `uvm_info("ERR014_SEQ",
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
    `uvm_info("ERR014_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR014_SEQ",
      "Starting TEST_ERROR_014: error response two-cycle window HRESP timing (HRESP@T4, window, ERR_INT, recover)",
      UVM_MEDIUM)

    // ── Step 1: configure CTRL=0x0000_0001 (ENABLE=1), verify clean ────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");        // expect 0x0000_0001

    // ── Step 2: good WRITE at 0x0000_3000 (PSLVERR=0) — completes OKAY ─────────
    // PSEL setup at T2, PENABLE active at T3, HREADY_OUT=1 at completion, HRESP=0.
    do_write(ADDR_GOOD_WR, DATA_GOOD_WR, "good_wr");          // PWDATA=0x0000_0F0F

    // ── Step 3: read STATUS — confirm clean (no sticky error bits) ─────────────
    do_read (REG_STATUS,     "status_clean");                // expect 0x0000_0001

    // ── Step 4: inject target error — WRITE at 0x0000_3100 with PSLVERR=1 ──────
    // PSEL=1,PENABLE=0 at T2; PSEL=1,PENABLE=1 at T3 active; PSLVERR=1,PREADY=1
    // sampled at the rising edge of T3.
    do_write(ADDR_PSLVERR, DATA_PSLVERR, "inject_pslverr");

    // ── Step 5: verify error detected — HRESP=1 at T4 held through window ───────
    // HRESP asserted at T4, held through error response window (T5..T6);
    // HREADY_OUT held low during the window then asserted at window close.
    do_read (REG_STATUS,     "status_pslverr");              // PSLVERR set sticky

    // ── Step 6: enable interrupt CTRL=0x0000_0009 then re-inject ───────────────
    // With ERR_INT_EN=1, the aggregated sticky interrupt indication fires.
    do_write(REG_CTRL,     CTRL_ENABLE_ERRINT, "ctrl_errint_en");
    do_write(ADDR_PSLVERR, DATA_PSLVERR,       "reinject_pslverr");
    do_read (REG_STATUS,     "status_errint");               // expect ERR_INT b7=1

    // ── Step 7: read error log type — STATUS=0x0000_00A1 (PSLVERR=1, ERR_INT=1) ─
    do_read (REG_STATUS,     "status_errclass");             // expect 0x0000_00A1

    // ── Step 8: read error info — ERROR_ADDR=0x3100, ERROR_INFO direction=write ─
    do_read (REG_ERROR_ADDR, "erraddr_pslverr");             // expect 0x0000_3100
    do_read (REG_ERROR_INFO, "errinfo_pslverr");             // direction=write, target-error

    // ── Step 9: clear interrupt — W1C bits 7 and 5 write STATUS=0x0000_00A0 ─────
    do_write(REG_STATUS, STATUS_W1C_ERRINT, "w1c_errint_pslverr");

    // ── Step 10: verify cleared — read STATUS (0x0000_0001) ────────────────────
    do_read (REG_STATUS,     "status_cleared");              // expect 0x0000_0001

    // ── Step 11: recovery — soft reset CTRL=0x0000_000B (SOFT_RST+ENABLE+ERR_INT_EN)
    // SOFT_RST clears active state + sticky flags + error log; config preserved.
    do_write(REG_CTRL,   CTRL_SOFT_RST, "ctrl_softrst");

    // ── Step 12: read error log after recovery — STATUS=0x0009, ERR regs clear ─
    do_read (REG_STATUS,     "status_recov");                // expect 0x0000_0009
    do_read (REG_ERROR_ADDR, "erraddr_recov");               // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");               // expect 0x0000_0000

    // ── Step 13: reconfigure — re-enable CTRL=0x0000_0001 (disable interrupt) ──
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reenable");
    do_read (REG_STATUS,              "status_reenable");    // expect 0x0000_0001

    // ── Step 14: post-recovery good READ at 0x0000_3104 -> PRDATA=0xCAFE_0001 ──
    do_read (ADDR_GOOD_RD,   "good_rd");                     // expect HRDATA=0xCAFE_0001, HRESP=0

    // ── Step 15: PROVE — re-read error log: STATUS/ERR_ADDR clean ──────────────
    do_read (REG_STATUS,     "status_final");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_final");               // expect 0x0000_0000

    `uvm_info("ERR014_SEQ", "TEST_ERROR_014 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_014_seq
