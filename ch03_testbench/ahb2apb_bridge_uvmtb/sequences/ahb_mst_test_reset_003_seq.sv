// =============================================================================
// FILE: sequences/ahb_mst_test_reset_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_003
// DESCRIPTION: Stimulus for soft_reset_preserves_basic_configuration.
//              Programs the full CTRL configuration (ENABLE, ERR_INT_EN,
//              TIMEOUT_VAL, TIMEOUT_EN), proves traffic works, drives the model
//              into a BUSY/transient state, asserts SOFT_RST while keeping the
//              config bits, holds N=4 cycles, clears SOFT_RST, then verifies the
//              configuration bits survived while transient/sticky STATUS was
//              cleared and operation resumes. All register accesses are raw AHB
//              transactions to PADDR 0xF00..0xF0C; data-plane traffic targets
//              the legal region 0x0000_0000-0xFFFF.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL   = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                    TIMEOUT_VAL b6:4, TIMEOUT_EN b7)
//   STATUS = 0xF04  (READY b0, BUSY b1)
//
// DERIVED FROM:
//   - XTP TEST_RESET_003 steps 1-10 — program CTRL=0xF9, read back, run write
//     traffic at 0x300 (0xDEADBEEF), read it back, drive BUSY state, assert
//     SOFT_RST (CTRL=0xFB), hold 4 cycles, clear SOFT_RST (CTRL=0xF9), read CTRL
//     (expect 0xF9 preserved) and STATUS (expect 0x1 transient cleared), then
//     prove resume with 0xCAFEBABE write/read-back at 0x300.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_003_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL   = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS = 32'h0000_0F04;

  // ── Data-plane address (legal region) ─────────────────────────────────────
  localparam logic [31:0] ADDR_DATA  = 32'h0000_0300;  // datapath traffic target

  // ── Control values ────────────────────────────────────────────────────────
  // CTRL_CONFIG: ENABLE b0, ERR_INT_EN b3, TIMEOUT_VAL b6:4=3'b111, TIMEOUT_EN b7
  localparam logic [31:0] CTRL_CONFIG   = 32'h0000_00F9;  // full config programmed
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_00FB;  // + SOFT_RST b1, config kept

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_FIRST = 32'hDEAD_BEEF;  // pre-reset traffic payload
  localparam logic [31:0] DATA_REUSE = 32'hCAFE_BABE;  // post-reset write proof

  function new(string name = "ahb_mst_test_reset_003_seq");
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
    `uvm_info("RST003_SEQ",
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
    `uvm_info("RST003_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST003_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST003_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    int unsigned c;

    `uvm_info("RST003_SEQ",
      "Starting TEST_RESET_003: soft-reset preserves basic configuration",
      UVM_MEDIUM)

    // ── T1: program full configuration (ENABLE+ERR_INT_EN+TIMEOUT_VAL+TIMEOUT_EN)
    do_write(REG_CTRL, CTRL_CONFIG, "ctrl_config");

    // ── T2: read back CTRL — expect 0xF9 (configuration written) ──────────────
    do_read(REG_CTRL, "ctrl_readback");

    // ── T3: send write traffic at 0x300 (0xDEADBEEF) — proves config active ───
    do_write(ADDR_DATA, DATA_FIRST, "traffic_wr");

    // ── T4: read back 0x300 — expect 0xDEADBEEF (traffic works) ───────────────
    do_read(ADDR_DATA, "traffic_rd");

    // ── T5: drive model into BUSY/transient state (start a stalled transfer) ──
    do_write(ADDR_DATA, DATA_FIRST, "busy_stall");
    do_read(REG_STATUS, "status_busy");

    // ── T6: assert SOFT_RST, retaining ENABLE/ERR_INT_EN/TIMEOUT_VAL/TIMEOUT_EN
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");

    // ── T6-T9: hold soft reset for N=4 cycles (transient state cleared) ───────
    for (c = 0; c < 4; c++) begin
      do_read(REG_STATUS, $sformatf("status_hold_%0d", c));
    end

    // ── T9: clear SOFT_RST keeping config (CTRL=0xF9, SOFT_RST self-cleared) ──
    do_write(REG_CTRL, CTRL_CONFIG, "ctrl_clear_softrst");

    // ── T10: read CTRL — expect 0xF9 (config bits preserved, SOFT_RST=0) ──────
    do_read(REG_CTRL, "ctrl_postrst");

    // ── T11: read STATUS — expect 0x1 (BUSY/sticky cleared, READY=1) ──────────
    do_read(REG_STATUS, "status_postrst");
    check_rdata(32'h0000_0001, "STATUS after SOFT_RST (transient state cleared)");

    // ── T12: prove resume — write 0xCAFEBABE at 0x300 and read it back ────────
    do_write(ADDR_DATA, DATA_REUSE, "reuse_wr");
    do_read (ADDR_DATA,             "reuse_rd");

    `uvm_info("RST003_SEQ", "TEST_RESET_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_003_seq
