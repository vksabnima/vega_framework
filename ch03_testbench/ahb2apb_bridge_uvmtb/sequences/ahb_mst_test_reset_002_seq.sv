// =============================================================================
// FILE: sequences/ahb_mst_test_reset_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_002
// DESCRIPTION: Stimulus for soft_reset_clears_sticky_status_flags.
//              Enables error handling, injects a target error (PSLVERR) to set
//              sticky STATUS flags, reads back STATUS/ERROR_ADDR, asserts
//              SOFT_RST to clear the sticky flags, holds, then proves the
//              debug-capture registers and STATUS returned to reset values and
//              the model recovered with a clean read-back. All register
//              accesses are raw AHB transactions to PADDR 0xF00..0xF0C;
//              data-plane traffic targets the legal region 0x0000_0000-0xFFFF.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, BUSY b1, PSLVERR b5, ERR_INT b7 sticky)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (captured debug info)
//
// DERIVED FROM:
//   - XTP TEST_RESET_002 steps 1-10 — enable error handling (CTRL=0x89),
//     inject target error at 0x200 (0xDEADBEEF, PSLVERR=1), read STATUS
//     (expect 0xA1) and ERROR_ADDR (expect 0x200), confirm idle/READY, assert
//     SOFT_RST (CTRL=0x8B), hold 4 cycles, read STATUS (expect 0x1) and
//     ERROR_ADDR/ERROR_INFO (expect 0x0), clear SOFT_RST (CTRL=0x1) and prove
//     clean re-use: write 0xCAFEBABE at 0x200 and read it back.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_002_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane address (legal region) ─────────────────────────────────────
  localparam logic [31:0] ADDR_DATA  = 32'h0000_0200;  // error-injection target

  // ── Control values ────────────────────────────────────────────────────────
  localparam logic [31:0] CTRL_ERR_ENABLE = 32'h0000_0089;  // ENABLE+ERR_INT_EN+TIMEOUT_EN
  localparam logic [31:0] CTRL_SOFT_RST   = 32'h0000_008B;  // + SOFT_RST b1
  localparam logic [31:0] CTRL_ENABLE     = 32'h0000_0001;  // ENABLE=1, SOFT_RST=0

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_ERR   = 32'hDEAD_BEEF;  // error-injection write payload
  localparam logic [31:0] DATA_REUSE = 32'hCAFE_BABE;  // post-reset write proof

  function new(string name = "ahb_mst_test_reset_002_seq");
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
    `uvm_info("RST002_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  logic [31:0] last_rdata;
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
    `uvm_info("RST002_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST002_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST002_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    int unsigned c;

    `uvm_info("RST002_SEQ",
      "Starting TEST_RESET_002: soft-reset clears sticky STATUS error flags",
      UVM_MEDIUM)

    // ── T1: enable error handling (ENABLE+ERR_INT_EN+TIMEOUT_EN) ──────────────
    do_write(REG_CTRL, CTRL_ERR_ENABLE, "ctrl_err_enable");

    // ── T2: inject a target error — write to 0x200, APB returns PSLVERR=1 ─────
    do_write(ADDR_DATA, DATA_ERR, "inject_err_wr");

    // ── T3: read STATUS — expect 0xA1 (ERR_INT b7, PSLVERR b5, READY b0) ──────
    do_read(REG_STATUS, "status_err");

    // ── T4: read ERROR_ADDR — expect 0x200 (captured failing address) ─────────
    do_read(REG_ERROR_ADDR, "error_addr_err");

    // ── T5: confirm model idle/READY (STATUS b0=1, BUSY b1=0) ─────────────────
    do_read(REG_STATUS, "status_idle");

    // ── T6: assert SOFT_RST, retaining ENABLE/ERR_INT_EN/TIMEOUT_EN ───────────
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");

    // ── T6-T9: hold soft reset for N=4 cycles (sticky flags cleared) ──────────
    for (c = 0; c < 4; c++) begin
      do_read(REG_STATUS, $sformatf("status_hold_%0d", c));
    end

    // ── T10: read STATUS — expect 0x1 (sticky bits cleared, READY=1) ──────────
    do_read(REG_STATUS, "status_postrst");
    check_rdata(32'h0000_0001, "STATUS after SOFT_RST (sticky flags cleared)");

    // ── T11: read debug-capture regs — expect ERROR_ADDR/INFO = 0x0 ───────────
    do_read(REG_ERROR_ADDR, "error_addr_postrst");
    do_read(REG_ERROR_INFO, "error_info_postrst");

    // ── T12: clear SOFT_RST (CTRL=0x1), then prove clean operation ────────────
    do_write(REG_CTRL,  CTRL_ENABLE, "ctrl_clear_softrst");
    do_write(ADDR_DATA, DATA_REUSE,  "reuse_wr");
    do_read (ADDR_DATA,              "reuse_rd");

    `uvm_info("RST002_SEQ", "TEST_RESET_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_002_seq
