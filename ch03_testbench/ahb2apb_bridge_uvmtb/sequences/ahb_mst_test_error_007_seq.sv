// =============================================================================
// FILE: sequences/ahb_mst_test_error_007_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_007
// DESCRIPTION: Stimulus for timeout_error_with_interrupt. Verifies that a
//              timeout error sets BOTH TIMEOUT_ERR (STATUS b6) and the
//              aggregated ERR_INT (STATUS b7) when interrupt indication is
//              enabled, captures debug context (ERROR_ADDR/ERROR_INFO), and that
//              ERR_INT and TIMEOUT_ERR each clear independently via W1C:
//                - configure CTRL=0x0000_00F9 (ENABLE b0=1, ERR_INT_EN b3=1,
//                  TIMEOUT_VAL=3'b111, TIMEOUT_EN b7=1) — timeout + interrupt on,
//                - a GOOD write at 0x0000_1000 (0x0000_0001) completes OKAY
//                  (HRESP=0, HREADY_OUT=1) with a clean STATUS,
//                - inject a timeout: a READ at 0x0000_6000 with the target
//                  stalled (PREADY held 0 past the TIMEOUT_VAL window) fires a
//                  timeout: HRESP=1, and STATUS sets TIMEOUT_ERR b6=1 AND
//                  ERR_INT b7=1 (STATUS=0x0000_00C1),
//                - the error log captures ERROR_ADDR=0x0000_6000 and ERROR_INFO
//                  (direction=read, coarse class=timeout),
//                - clear the interrupt: write STATUS=0x0000_0080 (W1C b7) — only
//                  ERR_INT clears, TIMEOUT_ERR stays set (STATUS=0x0000_0041),
//                - recovery: assert SOFT_RST (CTRL=0x0000_00FB) then deassert
//                  (CTRL=0x0000_00F9), and W1C TIMEOUT_ERR (STATUS=0x0000_0040)
//                  so BUSY clears, TIMEOUT_ERR clears, config preserved and the
//                  error log returns to 0,
//                - reconfigure CTRL=0x0000_00F9, then a post-recovery good READ
//                  at 0x0000_7000 returns 0xFEED_FACE (HRESP=0) proving data
//                  integrity with a clean STATUS log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4 cfg, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_007 steps 1-15 — configure CTRL=0x0000_00F9 (timeout +
//     interrupt enabled), good write at 0x0000_1000 (0x0000_0001), inject a
//     timeout via a stalled read at 0x0000_6000 (PREADY held 0 past the timeout
//     window), confirm TIMEOUT_ERR + ERR_INT both set (STATUS=0x0000_00C1) and
//     ERROR_ADDR=0x0000_6000, clear ERR_INT via W1C (STATUS=0x0000_0041),
//     recover via SOFT_RST + W1C TIMEOUT_ERR, reconfigure, post-recovery good
//     read at 0x0000_7000 (=0xFEED_FACE).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PREADY
//       stall, timeout-window, interrupt aggregation and error-log capture are
//       modelled in the APB slave / DUT; this sequence drives register and data
//       stimulus only, and the error-assertion / W1C checks live in the
//       scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_007_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_007_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good transfers stay inside the valid region. The injected read targets a
  // valid address but the target stalls (PREADY=0); with TIMEOUT_EN=1 this
  // provokes a timeout error and the aggregated interrupt indication.
  localparam logic [31:0] ADDR_GOOD_WR1  = 32'h0000_1000;  // good write
  localparam logic [31:0] DATA_GOOD_WR1  = 32'h0000_0001;
  localparam logic [31:0] ADDR_TIMEOUT   = 32'h0000_6000;  // stalled read -> timeout
  localparam logic [31:0] ADDR_GOOD_RD2  = 32'h0000_7000;  // post-recovery good rd
  localparam logic [31:0] DATA_GOOD_RD2  = 32'hFEED_FACE;  // expected PRDATA

  // ── Control / status values ───────────────────────────────────────────────
  // CTRL=0x00F9: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=1,
  //              TIMEOUT_VAL=3'b111, TIMEOUT_EN b7=1 (timeout + interrupt ON)
  localparam logic [31:0] CTRL_TIMEOUT_INT = 32'h0000_00F9; // enable + timeout + int
  // CTRL=0x00FB: same config but SOFT_RST b1=1 (recovery), then back to 0x00F9
  localparam logic [31:0] CTRL_SOFT_RST    = 32'h0000_00FB; // SOFT_RST asserted

  // ── STATUS W1C values ──────────────────────────────────────────────────────
  localparam logic [31:0] STATUS_W1C_ERRINT  = 32'h0000_0080; // W1C ERR_INT b7
  localparam logic [31:0] STATUS_W1C_TIMEOUT = 32'h0000_0040; // W1C TIMEOUT_ERR b6

  function new(string name = "ahb_mst_test_error_007_seq");
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
    `uvm_info("ERR007_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // ── Helper: drive a single word READ transaction ──────────────────────────
  logic [31:0] last_rdata;
  logic        last_resp;
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
    `uvm_info("ERR007_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR007_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR007_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR007_SEQ",
      "Starting TEST_ERROR_007: timeout error with interrupt indication",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_00F9 (timeout + interrupt ENABLED), verify ──
    do_write(REG_CTRL,   CTRL_TIMEOUT_INT, "ctrl_timeout_int");
    do_read (REG_CTRL,                     "ctrl_init");

    // ── T2: good WRITE traffic at valid address — must complete cleanly ───────
    do_write(ADDR_GOOD_WR1, DATA_GOOD_WR1, "good_wr1"); // expect HRESP=0, OKAY

    // ── T3: confirm clean STATUS before injection (0x0000_0001) ───────────────
    do_read (REG_STATUS,     "status_clean");

    // ── T4: inject timeout — READ to 0x0000_6000 with target stalled (PREADY=0) ─
    // With TIMEOUT_EN=1 the held completion eventually fires a timeout error.
    do_read (ADDR_TIMEOUT,   "inject_timeout");

    // ── T5..Tn+1: stall persists past timeout window; timeout fires (HRESP=1) ──
    // T7: STATUS — expect TIMEOUT_ERR b6=1 AND ERR_INT b7=1 (0x0000_00C1)
    do_read (REG_STATUS,     "status_timeout");
    check_rdata(32'h0000_00C1, "STATUS timeout+ERR_INT (READY|TIMEOUT_ERR|ERR_INT)");

    // ── T8: read error log — expect ERROR_ADDR=0x6000, ERROR_INFO captured ────
    do_read (REG_ERROR_ADDR, "erraddr_timeout");  // expect 0x0000_6000
    check_rdata(32'h0000_6000, "ERROR_ADDR captured timeout address");
    do_read (REG_ERROR_INFO, "errinfo_timeout");  // direction=read, class=timeout
    // ERR_TYPE[7:4]=2 (timeout), ERR_WRITE[3]=0 (read), ERR_SIZE[2:0]=2 => 0x22.
    check_rdata(32'h0000_0022, "ERROR_INFO timeout context (type=timeout,read,word)");

    // ── T9: clear interrupt — write STATUS=0x0000_0080 (W1C on ERR_INT b7) ────
    do_write(REG_STATUS, STATUS_W1C_ERRINT, "w1c_errint");

    // ── T10: read STATUS — ERR_INT cleared, TIMEOUT_ERR still set (0x0000_0041) ─
    do_read (REG_STATUS,     "status_int_cleared");

    // ── T11: recovery — SOFT_RST assert/deassert + W1C TIMEOUT_ERR ────────────
    do_write(REG_CTRL,   CTRL_SOFT_RST,      "ctrl_softrst");
    do_write(REG_CTRL,   CTRL_TIMEOUT_INT,   "ctrl_softrst_clr");
    do_write(REG_STATUS, STATUS_W1C_TIMEOUT, "w1c_timeout");

    // ── T12: read STATUS / error log after recovery — expect all cleared ──────
    do_read (REG_STATUS,     "status_recov");      // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_recov");     // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");     // expect 0x0000_0000

    // ── T13: reconfigure CTRL=0x0000_00F9 and verify STATUS ───────────────────
    do_write(REG_CTRL,   CTRL_TIMEOUT_INT, "ctrl_reconfig");
    do_read (REG_STATUS,                   "status_reconfig");

    // ── T14: post-recovery good READ at 0x0000_7000 — prove integrity ─────────
    do_read (ADDR_GOOD_RD2, "good_rd2");   // expect HRDATA=0xFEED_FACE, HRESP=0

    // ── T15: PROVE — read STATUS, verify clean data path / error log ──────────
    do_read (REG_STATUS,                    "status_final");

    `uvm_info("ERR007_SEQ", "TEST_ERROR_007 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_007_seq
