// =============================================================================
// FILE: sequences/ahb_mst_test_error_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_002
// DESCRIPTION: Stimulus for addr_error_boundary_just_outside_valid_range.
//              Exercises the boundary between the highest valid address and the
//              first address immediately above it:
//                - the LAST valid address  (0x0000_FFFC) must be ACCEPTED with
//                  no address error, and
//                - the FIRST invalid address (0x0001_0000), one location above
//                  the valid region top (0x0000_FFFF), must trigger ADDR_ERR
//                  and an HRESP error, with ERROR_ADDR capturing the exact
//                  boundary-violating address.
//              Followed by W1C clear, soft-reset recovery, and a post-recovery
//              good read at the last valid address. All accesses are raw AHB
//              transactions. Register accesses target the control/status block
//              at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ...)
//   STATUS     = 0xF04  (READY b0, ADDR_ERR b4, PSLVERR b5, TIMEOUT b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured invalid address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_002 steps 1-18 — configure, good write at last valid
//     address (0x0000_FFFC), inject boundary error at first invalid address
//     (0x0001_0000), capture ERROR_ADDR=0x0001_0000, W1C clear, soft-reset
//     recover, post-recovery good read at 0x0000_FFFC returns 0xABCD_1234.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_002_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Boundary addresses ────────────────────────────────────────────────────
  // Valid region top = 0x0000_FFFF; last word-aligned valid address = 0xFFFC.
  // First address just outside the valid range = 0x0001_0000.
  localparam logic [31:0] ADDR_LAST_VALID = 32'h0000_FFFC;  // accepted, no error
  localparam logic [31:0] ADDR_FIRST_INV  = 32'h0001_0000;  // boundary violation

  // ── Control / status values ───────────────────────────────────────────────
  localparam logic [31:0] CTRL_ENABLE    = 32'h0000_0001;  // ENABLE=1, TIMEOUT_EN=0
  localparam logic [31:0] CTRL_SOFT_RST  = 32'h0000_0003;  // ENABLE=1 + SOFT_RST=1
  localparam logic [31:0] STATUS_W1C     = 32'h0000_0090;  // W1C ERR_INT b7 + ADDR_ERR b4

  function new(string name = "ahb_mst_test_error_002_seq");
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
    `uvm_info("ERR002_SEQ",
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
    `uvm_info("ERR002_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR002_SEQ",
      "Starting TEST_ERROR_002: address-error boundary just outside valid range",
      UVM_MEDIUM)

    // ── T1: configure device, then verify CTRL/STATUS read-back ──────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_CTRL,                "ctrl_init");
    do_read (REG_STATUS,              "status_init");

    // ── T2-T4: good traffic at LAST VALID address — must be accepted ─────────
    do_write(ADDR_LAST_VALID, 32'hEDE0_0001, "good_lastvalid_wr");  // "EDGE" data

    // ── T5-T6: confirm clean error log before injection ──────────────────────
    do_read (REG_STATUS,     "status_clean");
    do_read (REG_ERROR_ADDR, "erraddr_clean");
    do_read (REG_ERROR_INFO, "errinfo_clean");

    // ── T7: inject boundary error — FIRST INVALID address 0x0001_0000 ────────
    do_write(ADDR_FIRST_INV, 32'h0E60_0001, "inject_boundary");  // "OVER" data

    // ── T8-T10: observe error detection and captured log ─────────────────────
    do_read (REG_STATUS,     "status_err");
    do_read (REG_ERROR_ADDR, "erraddr_capt");   // expect 0x0001_0000
    do_read (REG_ERROR_INFO, "errinfo_capt");

    // ── T11-T13: W1C clear of sticky flags (ERR_INT b7 + ADDR_ERR b4) ────────
    do_write(REG_STATUS, STATUS_W1C, "status_w1c");
    do_read (REG_STATUS,             "status_postclr");

    // ── T14: soft-reset recovery (assert SOFT_RST, then restore config) ──────
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");
    do_write(REG_CTRL, CTRL_ENABLE,   "ctrl_restore");

    // ── T15: read error log after recovery — expect clean ────────────────────
    do_read (REG_ERROR_ADDR, "erraddr_recov");
    do_read (REG_ERROR_INFO, "errinfo_recov");

    // ── T16: reconfigure and verify STATUS clean ─────────────────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");

    // ── T17-T18: post-recovery good read at LAST VALID addr returns 0xABCD_1234
    do_read (ADDR_LAST_VALID, "good_lastvalid_rd");

    // Final proof reads — error log must be clean after the good read.
    do_read (REG_STATUS,     "status_final");
    do_read (REG_ERROR_ADDR, "erraddr_final");
    do_read (REG_ERROR_INFO, "errinfo_final");

    `uvm_info("ERR002_SEQ", "TEST_ERROR_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_002_seq
