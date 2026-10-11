// =============================================================================
// FILE: sequences/ahb_mst_test_error_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_001
// DESCRIPTION: Stimulus for addr_error_basic_detection_capture.
//              Drives a clean configure -> good traffic -> address-error
//              injection -> error-log capture -> W1C clear -> soft-reset
//              recovery -> post-recovery good read flow, all as raw AHB
//              transactions. Register accesses target the control/status
//              block at PADDR 0xF00..0xF0C; data-plane traffic targets the
//              legal region 0x0000_0000-0x0000_FFFF; the error case targets
//              the invalid address 0xDEAD_0000.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ...)
//   STATUS     = 0xF04  (READY b0, ADDR_ERR b4, PSLVERR b5, TIMEOUT b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured invalid address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_001 steps 1-17 — configure, good write, inject address
//     error at 0xDEAD_0000, capture ERROR_ADDR, W1C clear, soft-reset recover,
//     post-recovery good read returns 0x1234_5678.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_001_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane addresses ──────────────────────────────────────────────────
  localparam logic [31:0] ADDR_GOOD_WR   = 32'h0000_1000;  // legal write target
  localparam logic [31:0] ADDR_GOOD_RD   = 32'h0000_2000;  // legal read target
  localparam logic [31:0] ADDR_INVALID   = 32'hDEAD_0000;  // invalid range

  // ── Control / status values ───────────────────────────────────────────────
  localparam logic [31:0] CTRL_ENABLE    = 32'h0000_0001;  // ENABLE=1, TIMEOUT_EN=0
  localparam logic [31:0] CTRL_SOFT_RST  = 32'h0000_0003;  // ENABLE=1 + SOFT_RST=1
  localparam logic [31:0] STATUS_W1C      = 32'h0000_00F0;  // clear bits 7,6,5,4

  function new(string name = "ahb_mst_test_error_001_seq");
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
    `uvm_info("ERR001_SEQ",
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
    `uvm_info("ERR001_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR001_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR001_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR001_SEQ",
      "Starting TEST_ERROR_001: address-error detection, capture, and recovery",
      UVM_MEDIUM)

    // ── T1: configure device, then verify STATUS read-back ───────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");

    // ── T2-T4: good pre-error write traffic (legal region) ───────────────────
    do_write(ADDR_GOOD_WR, 32'hCAFE_0001, "good_pre");

    // ── T5-T6: confirm clean error log before injection ──────────────────────
    do_read (REG_STATUS,     "status_clean");
    do_read (REG_ERROR_ADDR, "erraddr_clean");
    do_read (REG_ERROR_INFO, "errinfo_clean");

    // ── T7: inject address error — invalid range 0xDEAD_0000 ─────────────────
    do_write(ADDR_INVALID, 32'hBAD0_0001, "inject_err");

    // ── T8-T10: observe error detection and captured log ─────────────────────
    do_read (REG_STATUS,     "status_err");
    // Address-decode error sets ADDR_ERR(b4); ERR_INT_EN=0 so no ERR_INT(b7).
    // READY(b0) + ADDR_ERR(b4) => 0x11.
    check_rdata(32'h0000_0011, "STATUS after decode error (ADDR_ERR set)");
    do_read (REG_ERROR_ADDR, "erraddr_capt");
    check_rdata(ADDR_INVALID, "ERROR_ADDR captured invalid address");
    do_read (REG_ERROR_INFO, "errinfo_capt");

    // ── T11-T13: W1C clear of sticky flags, verify cleared ───────────────────
    do_write(REG_STATUS, STATUS_W1C, "status_w1c");
    do_read (REG_STATUS,             "status_postclr");
    check_rdata(32'h0000_0001, "STATUS after W1C clear of ADDR_ERR");

    // ── T13: soft-reset recovery (assert SOFT_RST, then restore config) ──────
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");
    do_write(REG_CTRL, CTRL_ENABLE,   "ctrl_restore");

    // ── T15: read error log after recovery — expect clean ────────────────────
    do_read (REG_ERROR_ADDR, "erraddr_recov");
    do_read (REG_ERROR_INFO, "errinfo_recov");

    // ── T16: reconfigure and verify STATUS clean ─────────────────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");

    // ── T17-T18: post-recovery good read returns 0x1234_5678 ─────────────────
    do_read (ADDR_GOOD_RD, "good_post");

    // Final proof reads — error log must be clean after the good read.
    do_read (REG_STATUS,     "status_final");
    do_read (REG_ERROR_ADDR, "erraddr_final");
    do_read (REG_ERROR_INFO, "errinfo_final");

    `uvm_info("ERR001_SEQ", "TEST_ERROR_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_001_seq
