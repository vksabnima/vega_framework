// =============================================================================
// FILE: sequences/ahb_mst_test_error_009_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_009
// DESCRIPTION: Stimulus for target_error_basic_pslverr_capture. Verifies a
//              single target-side error (PSLVERR=1) during an active access is
//              detected, propagated to HRESP, captured in ERROR_INFO/STATUS,
//              and that the model recovers cleanly with a clean error log:
//                - configure CTRL=0x0000_0001 (ENABLE b0=1, TIMEOUT_EN=0),
//                - a GOOD write at 0x0000_1000 (0xCAFE_0001) with PSLVERR=0
//                  completes OKAY (HRESP=0, HREADY_OUT=1, PWDATA/PADDR proven),
//                - confirm clean STATUS=0x0000_0001 before injection,
//                - inject target error: WRITE at 0x0000_2000 (0xDEAD_0002) with
//                  PSLVERR=1 at the target active phase — HRESP=1 (source-side
//                  error), STATUS.PSLVERR b5=1 sticky,
//                - check sticky aggregated interrupt STATUS.ERR_INT b7 (only set
//                  if ERR_INT_EN=1; this run leaves it disabled),
//                - read error log: ERROR_ADDR=0x0000_2000, ERROR_INFO captured
//                  (direction=write, coarse class=target-error),
//                - clear interrupt: write STATUS=0x0000_0080 (W1C ERR_INT b7),
//                - recovery: clear sticky PSLVERR write STATUS=0x0000_0020
//                  (W1C b5), then SOFT_RST via CTRL=0x0000_0003,
//                - read error log after recovery — STATUS=0x0000_0001,
//                  ERROR_ADDR=0, ERROR_INFO=0 (clean),
//                - reconfigure CTRL=0x0000_0001 (re-enable, SOFT_RST self-clear),
//                - post-recovery good READ at 0x0000_3000 returning PRDATA=
//                  0xBEEF_0003 proves data integrity (HRDATA=0xBEEF_0003,
//                  HRESP=0) with a clean STATUS log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3, TIMEOUT_EN b0..)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_009 steps 1-15 — configure CTRL=0x0000_0001, good write at
//     0x0000_1000 (0xCAFE_0001), confirm clean STATUS, inject PSLVERR=1 at
//     0x0000_2000 (0xDEAD_0002) -> HRESP=1, STATUS.PSLVERR b5=1, ERROR_ADDR=
//     0x0000_2000, W1C clears interrupt/sticky bits, SOFT_RST recovery clears
//     log, reconfigure, post-recovery good read at 0x0000_3000 (0xBEEF_0003).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PSLVERR
//       injection and error-log capture are modelled in the APB slave / DUT;
//       this sequence drives register and data stimulus only, and the error
//       propagation / W1C / recovery checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_009_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_009_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good transfers complete OKAY. The injected transfer raises PSLVERR=1 at the
  // target active phase, which the DUT propagates to HRESP and captures sticky.
  localparam logic [31:0] ADDR_GOOD_WR1  = 32'h0000_1000;  // good write
  localparam logic [31:0] DATA_GOOD_WR1  = 32'hCAFE_0001;
  localparam logic [31:0] ADDR_PSLVERR   = 32'h0000_2000;  // PSLVERR injection
  localparam logic [31:0] DATA_PSLVERR   = 32'hDEAD_0002;
  localparam logic [31:0] ADDR_GOOD_RD   = 32'h0000_3000;  // post-recovery read
  localparam logic [31:0] DATA_GOOD_RD   = 32'hBEEF_0003;  // expected PRDATA/HRDATA

  // ── Control / status values ───────────────────────────────────────────────
  // CTRL=0x0001: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=0, TIMEOUT_EN=0
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0001; // enable, no timeout
  // CTRL=0x0003: ENABLE b0=1 + SOFT_RST b1=1 (recovery), self-clears
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003; // SOFT_RST asserted

  // ── STATUS W1C values ──────────────────────────────────────────────────────
  localparam logic [31:0] STATUS_W1C_ERRINT  = 32'h0000_0080; // W1C ERR_INT b7
  localparam logic [31:0] STATUS_W1C_PSLVERR = 32'h0000_0020; // W1C PSLVERR b5

  function new(string name = "ahb_mst_test_error_009_seq");
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
    `uvm_info("ERR009_SEQ",
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
    `uvm_info("ERR009_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR009_SEQ",
      "Starting TEST_ERROR_009: target-side PSLVERR capture",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_0001 (ENABLE=1, TIMEOUT_EN=0), verify ───────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_CTRL,                "ctrl_init");        // expect 0x0000_0001

    // ── T2: good WRITE traffic at valid address (PSLVERR=0) — completes OKAY ───
    do_write(ADDR_GOOD_WR1, DATA_GOOD_WR1, "good_wr1");    // expect HRESP=0, OKAY

    // ── T3: confirm clean STATUS before injection (0x0000_0001) ───────────────
    do_read (REG_STATUS,     "status_clean");              // expect 0x0000_0001

    // ── T4: inject target error — WRITE at 0x0000_2000 with PSLVERR=1 ─────────
    // At the target active phase PSLVERR=1 fires; error capture triggered.
    do_write(ADDR_PSLVERR, DATA_PSLVERR, "inject_pslverr");

    // ── T5: read STATUS — expect PSLVERR b5=1 (sticky), HRESP=1 observed ──────
    do_read (REG_STATUS,     "status_pslverr");            // expect 0x0000_0021

    // ── T6: check sticky aggregated interrupt ERR_INT b7 (only if ERR_INT_EN) ─
    do_read (REG_STATUS,     "status_errint");             // ERR_INT=0 this run

    // ── T7: read error log type — STATUS.PSLVERR=1 -> target-error class ──────
    do_read (REG_STATUS,     "status_errclass");           // expect 0x0000_0021

    // ── T8: read error log — expect ERROR_ADDR=0x2000, ERROR_INFO captured ────
    do_read (REG_ERROR_ADDR, "erraddr_pslverr");           // expect 0x0000_2000
    do_read (REG_ERROR_INFO, "errinfo_pslverr");           // direction=write, target-error

    // ── T9: clear interrupt — write STATUS=0x0000_0080 (W1C ERR_INT b7) ───────
    do_write(REG_STATUS, STATUS_W1C_ERRINT, "w1c_errint");

    // ── T10: read STATUS — expect ERR_INT cleared ─────────────────────────────
    do_read (REG_STATUS,     "status_errint_clr");

    // ── T11: recovery — clear sticky PSLVERR (W1C b5), then SOFT_RST ──────────
    do_write(REG_STATUS, STATUS_W1C_PSLVERR, "w1c_pslverr");
    do_write(REG_CTRL,   CTRL_SOFT_RST,      "ctrl_softrst");

    // ── T12: read error log after recovery — expect clean (0x0/0x0/0x0001) ────
    do_read (REG_STATUS,     "status_recov");              // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_recov");             // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");             // expect 0x0000_0000

    // ── T13: reconfigure CTRL=0x0000_0001 (SOFT_RST self-cleared) and verify ──
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");  // expect 0x0000_0001

    // ── T14: post-recovery good READ at 0x0000_3000 -> PRDATA=0xBEEF_0003 ──────
    do_read (ADDR_GOOD_RD,   "good_rd");                   // expect HRDATA=0xBEEF_0003

    // ── T15: PROVE — read STATUS, verify clean data path / error log ──────────
    do_read (REG_STATUS,     "status_final");              // expect 0x0000_0001

    `uvm_info("ERR009_SEQ", "TEST_ERROR_009 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_009_seq
