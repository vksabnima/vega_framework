// =============================================================================
// FILE: sequences/ahb_mst_test_error_010_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_010
// DESCRIPTION: Stimulus for target_error_during_read_access. Verifies a target
//              error injected on a READ transfer is captured with read direction
//              in ERROR_INFO, HRDATA is NOT treated as a valid completion, and
//              recovery restores clean operation:
//                - configure CTRL=0x0000_0009 (ENABLE b0=1, ERR_INT_EN b3=1),
//                - a GOOD read at 0x0000_4000 returning PRDATA=0x1234_5678 with
//                  PSLVERR=0 completes OKAY (HRDATA=0x1234_5678, HRESP=0,
//                  HREADY_OUT=1),
//                - confirm clean STATUS=0x0000_0001 before injection,
//                - inject target error: READ at 0x0000_4004 with PSLVERR=1 at the
//                  target active phase (garbage PRDATA=0xFFFF_FFFF) — HRESP=1,
//                  STATUS.PSLVERR b5=1 sticky, HRDATA not used as valid data,
//                - check sticky aggregated interrupt STATUS.ERR_INT b7 (set here
//                  because ERR_INT_EN=1) — expect STATUS=0x0000_00A1,
//                - read error log: ERROR_ADDR=0x0000_4004, ERROR_INFO captured
//                  (direction=read, coarse class=target-error),
//                - clear interrupt: write STATUS=0x0000_0080 (W1C ERR_INT b7) ->
//                  STATUS=0x0000_0021 (PSLVERR still sticky),
//                - recovery: clear sticky PSLVERR write STATUS=0x0000_0020
//                  (W1C b5), then SOFT_RST via CTRL=0x0000_000B,
//                - read error log after recovery — STATUS=0x0000_0009,
//                  ERROR_ADDR=0, ERROR_INFO=0 (clean),
//                - reconfigure CTRL=0x0000_0009 (re-enable, SOFT_RST self-clear),
//                - post-recovery good READ at 0x0000_5000 returning PRDATA=
//                  0x0BADF00D proves data integrity (HRDATA=0x0BADF00D, HRESP=0)
//                  with a clean STATUS=0x0000_0009 log.
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
//   - XTP TEST_ERROR_010 steps 1-15 — configure CTRL=0x0000_0009, good read at
//     0x0000_4000 (0x1234_5678), confirm clean STATUS, inject PSLVERR=1 on a READ
//     at 0x0000_4004 (garbage 0xFFFF_FFFF) -> HRESP=1, STATUS.PSLVERR b5=1,
//     STATUS.ERR_INT b7=1 (STATUS=0x0000_00A1), ERROR_ADDR=0x0000_4004,
//     ERROR_INFO direction=read, W1C clears interrupt/sticky bits, SOFT_RST
//     recovery clears log, reconfigure, post-recovery good read at 0x0000_5000
//     (0x0BADF00D).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PSLVERR
//       injection and error-log capture are modelled in the APB slave / DUT;
//       this sequence drives register and data stimulus only, and the error
//       propagation / W1C / recovery checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_010_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_010_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good reads complete OKAY. The injected read raises PSLVERR=1 at the target
  // active phase, which the DUT propagates to HRESP and captures sticky; the
  // returned PRDATA must NOT be treated as a valid completion.
  localparam logic [31:0] ADDR_GOOD_RD1  = 32'h0000_4000;  // good read
  localparam logic [31:0] DATA_GOOD_RD1  = 32'h1234_5678;  // expected HRDATA
  localparam logic [31:0] ADDR_PSLVERR   = 32'h0000_4004;  // PSLVERR read injection
  localparam logic [31:0] DATA_PSLVERR   = 32'hFFFF_FFFF;  // garbage, must be discarded
  localparam logic [31:0] ADDR_GOOD_RD2  = 32'h0000_5000;  // post-recovery read
  localparam logic [31:0] DATA_GOOD_RD2  = 32'h0BAD_F00D;  // expected PRDATA/HRDATA

  // ── Control / status values ───────────────────────────────────────────────
  // CTRL=0x0009: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=1
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0009; // enable + err interrupt
  // CTRL=0x000B: ENABLE b0=1 + SOFT_RST b1=1 + ERR_INT_EN b3=1 (recovery)
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_000B; // SOFT_RST asserted

  // ── STATUS W1C values ──────────────────────────────────────────────────────
  localparam logic [31:0] STATUS_W1C_ERRINT  = 32'h0000_0080; // W1C ERR_INT b7
  localparam logic [31:0] STATUS_W1C_PSLVERR = 32'h0000_0020; // W1C PSLVERR b5

  function new(string name = "ahb_mst_test_error_010_seq");
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
    `uvm_info("ERR010_SEQ",
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
    `uvm_info("ERR010_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR010_SEQ",
      "Starting TEST_ERROR_010: target error during read access",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_0009 (ENABLE=1, ERR_INT_EN=1), verify ───────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_CTRL,                "ctrl_init");        // expect 0x0000_0009
    do_read (REG_STATUS,              "status_init");      // expect 0x0000_0001

    // ── T2: good READ at valid address (PSLVERR=0) — completes OKAY ───────────
    do_read (ADDR_GOOD_RD1,  "good_rd1");                  // expect HRDATA=0x1234_5678

    // ── T3: confirm clean STATUS before injection (0x0000_0001) ───────────────
    do_read (REG_STATUS,     "status_clean");              // expect 0x0000_0001

    // ── T4: inject target error — READ at 0x0000_4004 with PSLVERR=1 ──────────
    // At the target active phase PSLVERR=1 fires (garbage PRDATA); error capture
    // triggered, read data deemed invalid.
    do_read (ADDR_PSLVERR,   "inject_pslverr");

    // ── T5: read STATUS — expect PSLVERR b5=1 (sticky), HRESP=1 observed ──────
    do_read (REG_STATUS,     "status_pslverr");            // PSLVERR set; HRDATA not valid

    // ── T6: check interrupt asserted (ERR_INT_EN=1) -> ERR_INT b7=1 ───────────
    do_read (REG_STATUS,     "status_errint");             // expect ERR_INT=1

    // ── T7: read error log type — STATUS=0x0000_00A1, target-error class ──────
    do_read (REG_STATUS,     "status_errclass");           // expect 0x0000_00A1

    // ── T8: read error log — ERROR_ADDR=0x4004, ERROR_INFO direction=read ─────
    do_read (REG_ERROR_ADDR, "erraddr_pslverr");           // expect 0x0000_4004
    do_read (REG_ERROR_INFO, "errinfo_pslverr");           // direction=read, target-error

    // ── T9: clear interrupt — write STATUS=0x0000_0080 (W1C ERR_INT b7) ───────
    do_write(REG_STATUS, STATUS_W1C_ERRINT, "w1c_errint");

    // ── T10: read STATUS — ERR_INT cleared, PSLVERR still sticky (0x0000_0021) ─
    do_read (REG_STATUS,     "status_errint_clr");         // expect 0x0000_0021

    // ── T11: recovery — clear sticky PSLVERR (W1C b5), then SOFT_RST ──────────
    do_write(REG_STATUS, STATUS_W1C_PSLVERR, "w1c_pslverr");
    do_write(REG_CTRL,   CTRL_SOFT_RST,      "ctrl_softrst");

    // ── T12: read error log after recovery — expect clean (0x0009/0x0/0x0) ────
    do_read (REG_STATUS,     "status_recov");              // expect 0x0000_0009
    do_read (REG_ERROR_ADDR, "erraddr_recov");             // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");             // expect 0x0000_0000

    // ── T13: reconfigure CTRL=0x0000_0009 (SOFT_RST self-cleared) and verify ──
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");  // expect 0x0000_0009 / READY=1

    // ── T14: post-recovery good READ at 0x0000_5000 -> PRDATA=0x0BAD_F00D ──────
    do_read (ADDR_GOOD_RD2,  "good_rd2");                  // expect HRDATA=0x0BADF00D

    // ── T15: PROVE — read STATUS, verify clean data path / error log ──────────
    do_read (REG_STATUS,     "status_final");              // expect 0x0000_0009

    `uvm_info("ERR010_SEQ", "TEST_ERROR_010 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_010_seq
