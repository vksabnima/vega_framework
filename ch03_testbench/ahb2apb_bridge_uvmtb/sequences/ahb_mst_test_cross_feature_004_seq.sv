// =============================================================================
// FILE: sequences/ahb_mst_test_cross_feature_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CROSS_FEATURE_004
// DESCRIPTION: Stimulus for soft_reset_clears_sticky_error. Exposes incomplete
//              soft-reset behavior: SOFT_RST clears active transfer state but may
//              fail to clear previously latched sticky STATUS error flags or stale
//              ERROR_ADDR/ERROR_INFO. Neither the error feature nor the soft-reset
//              feature alone covers this — the bug only appears when an error is
//              provoked FIRST and a soft reset is applied AFTER.
//
//              All stimulus is issued as raw AHB transactions. Register accesses
//              target the control/status block at PADDR 0xF00..0xF0C; the erroring
//              data-plane write targets the legal region 0x0000_0000-0x0000_FFFF.
//              The PSLVERR=1 completion is produced by the APB slave / tb harness;
//              the scoreboard validates that the soft reset clears the sticky error
//              state (STATUS=0x00000001, ERROR_ADDR=0, ERROR_INFO=0) while
//              preserving CTRL configuration (ENABLE) and self-clearing SOFT_RST.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ...)
//   STATUS     = 0xF04  (READY b0, BUSY b1, sticky PSLVERR / ERR_INT bits, ...)
//   ERROR_ADDR = 0xF08  (captured faulting address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_004 steps T1-T7 — provoke an erroring write
//     (0x0000_5000 = 0x1234_5678, peripheral asserts PSLVERR=1), read STATUS /
//     ERROR_ADDR / ERROR_INFO to confirm sticky state, write CTRL with SOFT_RST
//     (bit1=1), read back CTRL (SOFT_RST self-cleared, ENABLE preserved), then
//     read STATUS / ERROR_ADDR / ERROR_INFO to confirm the sticky error context
//     was cleared by the soft reset.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_cross_feature_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_cross_feature_004_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane address / payload for the erroring transfer ──────────────────
  localparam logic [31:0] ADDR_ERR  = 32'h0000_5000;  // erroring write addr
  localparam logic [31:0] DATA_ERR  = 32'h1234_5678;  // payload of erroring write

  // ── CTRL write value: SOFT_RST (bit1) = 1, ENABLE (bit0) preserved = 1 ──────
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003;

  function new(string name = "ahb_mst_test_cross_feature_004_seq");
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
    `uvm_info("XFEAT004_SEQ",
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
    `uvm_info("XFEAT004_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("XFEAT004_SEQ",
      "Starting TEST_CROSS_FEATURE_004: soft reset clears sticky error",
      UVM_MEDIUM)

    // ── T1-T2: provoke the error — erroring write that the peripheral completes ─
    // with PSLVERR=1. Transfer captured/forwarded (FLOW-1..FLOW-3); HRESP=1
    // returned to source and the error context (addr/direction/class) latched
    // into the sticky STATUS bits + ERROR_ADDR/ERROR_INFO. The PSLVERR=1
    // completion is produced by the APB slave / tb harness.
    do_write(ADDR_ERR, DATA_ERR, "err_write");

    // ── T3: read STATUS / ERROR_ADDR / ERROR_INFO — confirm sticky state set ───
    // (STATUS PSLVERR=1 & ERR_INT=1; ERROR_ADDR=0x0000_5000; ERROR_INFO non-zero).
    do_read(REG_STATUS,     "status_after_err");
    do_read(REG_ERROR_ADDR, "erraddr_after_err");
    do_read(REG_ERROR_INFO, "errinfo_after_err");

    // ── T4: write CTRL with SOFT_RST (bit1=1), ENABLE (bit0) preserved =1 ──────
    // Triggers a model-local soft reset that must clear active transfer state and
    // (per pass criteria) the sticky error flags + stale error context.
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_soft_rst");

    // ── T5: read back CTRL — SOFT_RST is self-clearing (reads back 0); ENABLE ──
    // and other config knobs preserved per Table 5.
    do_read(REG_CTRL, "ctrl_readback");

    // ── T6: read back STATUS — sticky error flags cleared by the soft reset ────
    // (expect STATUS=0x0000_0001: PSLVERR=0, ERR_INT=0, BUSY=0, READY=1).
    do_read(REG_STATUS, "status_after_rst");

    // ── T7: read ERROR_ADDR / ERROR_INFO — stale error context cleared ─────────
    // (expect both 0x0000_0000).
    do_read(REG_ERROR_ADDR, "erraddr_after_rst");
    do_read(REG_ERROR_INFO, "errinfo_after_rst");

    `uvm_info("XFEAT004_SEQ", "TEST_CROSS_FEATURE_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_cross_feature_004_seq
