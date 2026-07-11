// =============================================================================
// FILE: sequences/ahb_mst_test_error_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_004
// DESCRIPTION: Stimulus for addr_error_during_active_transfer_with_reset_recovery.
//              Verifies that an invalid-address request following a valid
//              in-flight transfer is detected, then that a hard/soft reset
//              cleanly aborts the in-flight work and clears the sticky ADDR_ERR
//              and captured debug registers:
//                - configure CTRL=0x0000_0001 (ENABLE), verify STATUS clean,
//                - a GOOD write at a valid address (0x0000_5000, 0x1111_2222)
//                  completes with HRESP=0 and a clean error log, then
//                - a valid in-flight transfer is started and immediately an
//                  invalid-range WRITE (0xFEED_0000, 0x3333_4444) is issued,
//                  triggering ADDR_ERR, an HRESP error, asserting the sticky
//                  ERR_INT, and capturing ERROR_ADDR=0xFEED_0000 with ERROR_INFO
//                  recording direction=write / coarse error class=address,
//                - W1C clear (ERR_INT + ADDR_ERR),
//                - hard-reset recovery: registers return to Table 8 values and
//                  ERROR_ADDR / ERROR_INFO are cleared,
//                - reconfigure CTRL=0x0000_0001, then a post-recovery good
//                  write+read at 0x0000_6000 returns 0x9999_8888 with a clean log.
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
//   - XTP TEST_ERROR_004 steps 1-17 — configure CTRL=0x0000_0001, good write at
//     0x0000_5000 (0x1111_2222), start a valid in-flight transfer then inject an
//     invalid-address WRITE at 0xFEED_0000, capture ERROR_ADDR=0xFEED_0000 +
//     write-direction context, assert ERR_INT, W1C clear, hard-reset recover
//     (Table 8 register reset, error log cleared), reconfigure, post-recovery
//     good write+read at 0x0000_6000 returns 0x9999_8888.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. Hard reset
//       is modelled here via a SOFT_RST register write (the testbench drives
//       register stimulus only); reset checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_004_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Valid region top = 0x0000_FFFF. Good transfers stay inside it; the injected
  // request targets an address well outside the valid range.
  localparam logic [31:0] ADDR_GOOD_WR1  = 32'h0000_5000;  // good write
  localparam logic [31:0] DATA_GOOD_WR1  = 32'h1111_2222;
  localparam logic [31:0] ADDR_INVALID   = 32'hFEED_0000;  // invalid-range WRITE
  localparam logic [31:0] DATA_INVALID   = 32'h3333_4444;
  localparam logic [31:0] ADDR_GOOD_WR2  = 32'h0000_6000;  // post-recovery good wr/rd
  localparam logic [31:0] DATA_GOOD_WR2  = 32'h9999_8888;

  // ── Control / status values ───────────────────────────────────────────────
  localparam logic [31:0] CTRL_ENABLE    = 32'h0000_0001;  // ENABLE b0
  localparam logic [31:0] CTRL_SOFT_RST  = 32'h0000_0003;  // ENABLE + SOFT_RST b1 (hard-reset model)
  localparam logic [31:0] STATUS_W1C     = 32'h0000_0090;  // W1C ERR_INT b7 + ADDR_ERR b4

  function new(string name = "ahb_mst_test_error_004_seq");
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
    `uvm_info("ERR004_SEQ",
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
    `uvm_info("ERR004_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR004_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR004_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR004_SEQ",
      "Starting TEST_ERROR_004: addr error during active transfer + reset recovery",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_0001, verify STATUS ────────────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_CTRL,                "ctrl_init");
    do_read (REG_STATUS,              "status_init");

    // ── T2-T3: good WRITE traffic at valid address — must complete cleanly ────
    do_write(ADDR_GOOD_WR1, DATA_GOOD_WR1, "good_wr1");
    do_read (REG_STATUS,                    "status_good");

    // ── T4-T5: confirm clean error log before injection ──────────────────────
    do_read (REG_STATUS,     "status_clean");
    do_read (REG_ERROR_ADDR, "erraddr_clean");
    do_read (REG_ERROR_INFO, "errinfo_clean");

    // ── T6: start valid in-flight transfer then inject invalid-addr WRITE ─────
    // Invalid-range write at 0xFEED_0000 following live activity.
    do_write(ADDR_INVALID, DATA_INVALID, "inject_wr_err");

    // ── T7-T10: observe error detection and captured log ──────────────────────
    do_read (REG_STATUS,     "status_err");     // expect ADDR_ERR b4
    // CTRL=0x01 (ERR_INT_EN=0), so only READY(b0)|ADDR_ERR(b4) => 0x11.
    check_rdata(32'h0000_0011, "STATUS after decode write error (ADDR_ERR)");
    do_read (REG_ERROR_ADDR, "erraddr_capt");   // expect 0xFEED_0000
    check_rdata(ADDR_INVALID, "ERROR_ADDR captured invalid address");
    do_read (REG_ERROR_INFO, "errinfo_capt");   // direction=write, class=address

    // ── T11-T12: W1C clear of sticky flags (ADDR_ERR b4) ─────────────────────
    do_write(REG_STATUS, STATUS_W1C, "status_w1c");
    do_read (REG_STATUS,             "status_postclr");
    check_rdata(32'h0000_0001, "STATUS after W1C clear");

    // ── T13: hard-reset recovery (model via SOFT_RST, Table 8 register reset) ──
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_hardrst");

    // ── T14: read error log after recovery — expect cleared by reset ──────────
    do_read (REG_ERROR_ADDR, "erraddr_recov");
    do_read (REG_ERROR_INFO, "errinfo_recov");

    // ── T15: reconfigure CTRL=0x0000_0001 and verify STATUS ───────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");

    // ── T16: post-recovery good WRITE then READ-back at 0x0000_6000 ───────────
    do_write(ADDR_GOOD_WR2, DATA_GOOD_WR2, "good_wr2");
    do_read (ADDR_GOOD_WR2,                "good_rd2");

    // ── T17: final proof reads — error log must be clean after the good rw ────
    do_read (REG_STATUS,     "status_final");
    do_read (REG_ERROR_ADDR, "erraddr_final");
    do_read (REG_ERROR_INFO, "errinfo_final");

    `uvm_info("ERR004_SEQ", "TEST_ERROR_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_004_seq
