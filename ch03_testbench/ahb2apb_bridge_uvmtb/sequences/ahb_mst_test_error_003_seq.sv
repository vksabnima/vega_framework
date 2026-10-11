// =============================================================================
// FILE: sequences/ahb_mst_test_error_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_003
// DESCRIPTION: Stimulus for addr_error_read_direction_context_capture.
//              Verifies that an invalid-address READ transaction is detected:
//                - a GOOD read at a valid address (0x0000_3000) completes with
//                  HRDATA=0x5555_AAAA, HRESP=0, and a clean error log, then
//                - an invalid-range READ (0xBEEF_0000) triggers ADDR_ERR, an
//                  HRESP error, asserts the sticky ERR_INT (since ERR_INT_EN=1),
//                  and captures ERROR_ADDR=0xBEEF_0000 with ERROR_INFO recording
//                  direction=read / coarse error class=address. HRDATA must NOT
//                  be presented as valid (no target access launched).
//              Followed by W1C clear (ERR_INT + ADDR_ERR), soft-reset recovery
//              that preserves the ERR_INT_EN config, and a post-recovery good
//              read at 0x0000_4000 returning 0x0F0F_F0F0 with a clean log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ERR_INT_EN bit3, ...)
//   STATUS     = 0xF04  (READY b0, ADDR_ERR b4, PSLVERR b5, TIMEOUT b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured invalid address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_003 steps 1-18 — configure with ERR_INT_EN=1, good read at
//     0x0000_3000 (PRDATA=0x5555_AAAA), inject address error on READ at
//     0xBEEF_0000, capture ERROR_ADDR=0xBEEF_0000 + read-direction context,
//     assert ERR_INT, W1C clear, soft-reset recover preserving config,
//     post-recovery good read at 0x0000_4000 returns 0x0F0F_F0F0.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_003_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Read addresses ────────────────────────────────────────────────────────
  // Valid region top = 0x0000_FFFF. Good reads stay inside it; the injected
  // read targets an address well outside the valid range.
  localparam logic [31:0] ADDR_GOOD_RD1 = 32'h0000_3000;  // good read, returns 0x5555_AAAA
  localparam logic [31:0] ADDR_INVALID  = 32'hBEEF_0000;  // invalid-range READ
  localparam logic [31:0] ADDR_GOOD_RD2 = 32'h0000_4000;  // post-recovery good read

  // ── Control / status values ───────────────────────────────────────────────
  localparam logic [31:0] CTRL_INT_EN    = 32'h0000_0009;  // ENABLE b0 + ERR_INT_EN b3
  localparam logic [31:0] CTRL_SOFT_RST  = 32'h0000_000B;  // ENABLE + ERR_INT_EN + SOFT_RST b1
  localparam logic [31:0] STATUS_W1C     = 32'h0000_0090;  // W1C ERR_INT b7 + ADDR_ERR b4

  function new(string name = "ahb_mst_test_error_003_seq");
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
    `uvm_info("ERR003_SEQ",
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
    `uvm_info("ERR003_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR003_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR003_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR003_SEQ",
      "Starting TEST_ERROR_003: invalid-address READ detection + read-direction context capture",
      UVM_MEDIUM)

    // ── T1: configure with interrupt enable, then verify CTRL/STATUS read-back
    do_write(REG_CTRL,   CTRL_INT_EN, "ctrl_int_en");  // ENABLE=1 + ERR_INT_EN=1
    do_read (REG_CTRL,                "ctrl_init");
    do_read (REG_STATUS,              "status_init");

    // ── T2-T4: good READ traffic at valid address — must be accepted ─────────
    // APB slave model returns the target data; expect HRDATA=0x5555_AAAA.
    do_read (ADDR_GOOD_RD1, "good_rd1");

    // ── T5-T6: confirm clean error log before injection ──────────────────────
    do_read (REG_STATUS,     "status_clean");
    do_read (REG_ERROR_ADDR, "erraddr_clean");
    do_read (REG_ERROR_INFO, "errinfo_clean");

    // ── T7: inject address error on READ — invalid-range addr 0xBEEF_0000 ────
    do_read (ADDR_INVALID, "inject_rd_err");

    // ── T8-T10: observe error detection and captured log ──────────────────────
    do_read (REG_STATUS,     "status_err");     // expect ADDR_ERR b4 + ERR_INT b7
    // ERR_INT_EN=1 here, so READY(b0)|ADDR_ERR(b4)|ERR_INT(b7) => 0x91.
    check_rdata(32'h0000_0091, "STATUS after decode error (ADDR_ERR+ERR_INT)");
    do_read (REG_ERROR_ADDR, "erraddr_capt");   // expect 0xBEEF_0000
    check_rdata(ADDR_INVALID, "ERROR_ADDR captured invalid address");
    do_read (REG_ERROR_INFO, "errinfo_capt");   // direction=read, class=address

    // ── T11-T13: W1C clear of sticky flags (ERR_INT b7 + ADDR_ERR b4) ────────
    do_write(REG_STATUS, STATUS_W1C, "status_w1c");
    do_read (REG_STATUS,             "status_postclr");
    check_rdata(32'h0000_0001, "STATUS after W1C clear");

    // ── T14: soft-reset recovery (assert SOFT_RST, preserve ERR_INT_EN) ──────
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");
    do_write(REG_CTRL, CTRL_INT_EN,   "ctrl_restore");

    // ── T15: read error log after recovery — expect clean ────────────────────
    do_read (REG_ERROR_ADDR, "erraddr_recov");
    do_read (REG_ERROR_INFO, "errinfo_recov");

    // ── T16: reconfigure and verify STATUS clean ─────────────────────────────
    do_write(REG_CTRL,   CTRL_INT_EN, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");

    // ── T17-T18: post-recovery good READ at 0x0000_4000 returns 0x0F0F_F0F0 ───
    do_read (ADDR_GOOD_RD2, "good_rd2");

    // Final proof reads — error log must be clean after the good read.
    do_read (REG_STATUS,     "status_final");
    do_read (REG_ERROR_ADDR, "erraddr_final");
    do_read (REG_ERROR_INFO, "errinfo_final");

    `uvm_info("ERR003_SEQ", "TEST_ERROR_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_003_seq
