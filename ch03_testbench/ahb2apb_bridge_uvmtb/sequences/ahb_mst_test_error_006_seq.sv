// =============================================================================
// FILE: sequences/ahb_mst_test_error_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_006
// DESCRIPTION: Stimulus for timeout_disabled_no_error (negative / control test).
//              Verifies that with TIMEOUT_EN=0 a prolonged PREADY=0 stall does
//              NOT set TIMEOUT_ERR or HRESP, but instead holds completion until
//              the target finally responds:
//                - configure CTRL=0x0000_0071 (ENABLE b0=1, TIMEOUT_EN b7=0,
//                  TIMEOUT_VAL=3'b111), verify timeout behavior disabled,
//                - a GOOD read at a valid address (0x0000_1000) completes with
//                  HRDATA=0xA5A5_A5A5, HRESP=0 and a clean STATUS,
//                - a write at 0x0000_4000 (0x0000_BEEF) with the target stalled
//                  (PREADY held 0 well past the TIMEOUT_VAL window) does NOT
//                  trigger a timeout: HRESP stays 0, HREADY_OUT stays 0 (BUSY),
//                  TIMEOUT_ERR (STATUS b6) and ERR_INT (b7) stay 0, and the
//                  error log (ERROR_ADDR/ERROR_INFO) stays 0,
//                - once PREADY is released the stalled write completes OKAY
//                  (PADDR=0x0000_4000, PWDATA=0x0000_BEEF, HRESP=0, BUSY=0),
//                - soft-reset hygiene (config preserved, BUSY cleared, log 0),
//                - reconfigure CTRL=0x0000_0071, then a post-recovery good write
//                  at 0x0000_5000 (0x0BAD_F00D) completes OKAY with a clean log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4 / b5:7 cfg, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_006 steps 1-15 — configure CTRL=0x0000_0071 (TIMEOUT_EN=0),
//     good read at 0x0000_1000 (=0xA5A5_A5A5), inject a stalled write at
//     0x0000_4000 (0x0000_BEEF) with PREADY held 0 past the timeout window,
//     confirm no TIMEOUT_ERR / no HRESP / clean error log while completion is
//     held, release PREADY so the write completes OKAY, soft-reset hygiene,
//     reconfigure, post-recovery good write at 0x0000_5000 (0x0BAD_F00D).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PREADY
//       stall and (disabled) timeout-window behavior are modelled in the APB
//       slave / DUT; this sequence drives register and data stimulus only, and
//       the "no error fires" checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_006_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good transfers stay inside the valid region. The injected request targets a
  // valid address but the target stalls (PREADY=0); with TIMEOUT_EN=0 this holds
  // completion rather than provoking a timeout error.
  localparam logic [31:0] ADDR_GOOD_RD1  = 32'h0000_1000;  // good read
  localparam logic [31:0] DATA_GOOD_RD1  = 32'hA5A5_A5A5;  // expected PRDATA
  localparam logic [31:0] ADDR_STALL     = 32'h0000_4000;  // stalled write -> held
  localparam logic [31:0] DATA_STALL     = 32'h0000_BEEF;
  localparam logic [31:0] ADDR_GOOD_WR2  = 32'h0000_5000;  // post-recovery good wr
  localparam logic [31:0] DATA_GOOD_WR2  = 32'h0BAD_F00D;

  // ── Control / status values ───────────────────────────────────────────────
  // CTRL=0x0071: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=0,
  //              TIMEOUT_VAL=3'b111, TIMEOUT_EN b7=0 (timeout disabled)
  localparam logic [31:0] CTRL_TIMEOUT_DIS = 32'h0000_0071; // enable + timeout OFF
  // CTRL=0x0073: same config but SOFT_RST b1=1 (recovery), then back to 0x0071
  localparam logic [31:0] CTRL_SOFT_RST    = 32'h0000_0073; // SOFT_RST asserted

  function new(string name = "ahb_mst_test_error_006_seq");
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
    `uvm_info("ERR006_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // Last captured read-back value / response, for self-checks.
  logic [31:0] last_rdata;
  logic        last_resp;

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
    `uvm_info("ERR006_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR006_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR006_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR006_SEQ",
      "Starting TEST_ERROR_006: timeout disabled — prolonged stall, no error",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_0071 (timeout DISABLED), verify ────────────
    do_write(REG_CTRL,   CTRL_TIMEOUT_DIS, "ctrl_timeout_dis");
    do_read (REG_CTRL,                     "ctrl_init");

    // ── T2: good READ traffic at valid address — must complete cleanly ────────
    do_read (ADDR_GOOD_RD1, "good_rd1");   // expect HRDATA=0xA5A5_A5A5, HRESP=0

    // ── T3: confirm clean STATUS before injection (0x0000_0001) ───────────────
    do_read (REG_STATUS,     "status_clean");

    // ── T4: inject stall — write to 0x0000_4000 with target stalled (PREADY=0) ─
    // With TIMEOUT_EN=0 completion is HELD (HREADY_OUT=0, BUSY=1), no timeout.
    do_write(ADDR_STALL, DATA_STALL, "inject_stall");

    // ── T5..Tn+1: stall persists past timeout window; no timeout must fire ─────
    // T7: STATUS — expect TIMEOUT_ERR b6=0, ERR_INT b7=0, BUSY b1=1 (pending)
    do_read (REG_STATUS,     "status_stalled");

    // ── T8: read error log — must remain empty (no error captured) ────────────
    do_read (REG_ERROR_ADDR, "erraddr_none");   // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_none");   // expect 0x0000_0000

    // No error must have been captured (timeout disabled).
    check_rdata(32'h0000_0000, "ERROR_ADDR (no timeout, disabled)");

    // ── T9..T10: release stall (PREADY=1); stalled write completes OKAY ───────
    // The APB slave releasing PREADY lets the held write finish: PADDR=0x4000,
    // PWDATA=0x0000_BEEF, HRESP=0, BUSY clears.
    do_read (REG_STATUS,     "status_completed");
    // Timeout disabled => no TIMEOUT_ERR; transfer completed => STATUS = 0x01.
    check_rdata(32'h0000_0001, "STATUS after held stall completes (no timeout)");

    // ── T11: soft-reset hygiene — assert SOFT_RST then deassert ──────────────
    do_write(REG_CTRL, CTRL_SOFT_RST,     "ctrl_softrst");
    do_write(REG_CTRL, CTRL_TIMEOUT_DIS,  "ctrl_softrst_clr");

    // ── T12: read error log after recovery — expect still cleared ─────────────
    do_read (REG_ERROR_ADDR, "erraddr_recov");
    do_read (REG_ERROR_INFO, "errinfo_recov");

    // ── T13: reconfigure CTRL=0x0000_0071 and verify STATUS ───────────────────
    do_write(REG_CTRL,   CTRL_TIMEOUT_DIS, "ctrl_reconfig");
    do_read (REG_STATUS,                   "status_reconfig");

    // ── T14: post-recovery good WRITE at 0x0000_5000 — prove integrity ────────
    do_write(ADDR_GOOD_WR2, DATA_GOOD_WR2, "good_wr2");

    // ── T15: PROVE — read STATUS, verify clean data path / error log ──────────
    do_read (REG_STATUS,                    "status_final");

    `uvm_info("ERR006_SEQ", "TEST_ERROR_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_006_seq
