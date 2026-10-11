// =============================================================================
// FILE: sequences/ahb_mst_test_reset_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_004
// DESCRIPTION: Stimulus for soft_reset_vs_hard_reset_value_comparison.
//              Exercises the distinction between SOFT_RST (preserves the CTRL
//              configuration while clearing STATUS sticky state) and a full
//              HRESETn hard reset (restores ALL registers to Table 8 defaults,
//              including CTRL). The flow:
//                1. read the hard-reset default register values (Table 8),
//                2. program a non-default CTRL (0xF9),
//                3. induce a sticky PSLVERR error (ERROR_ADDR/STATUS set),
//                4. assert SOFT_RST (CTRL=0xFB), hold N=4 cycles, clear (0xF9)
//                   — CTRL preserved, STATUS/ERROR_ADDR cleared,
//                5. apply a full hard reset (pulse HRESETn) — CTRL back to 0x1,
//                6. prove operational with a 0xCAFEBABE write/read-back.
//              All register accesses are raw AHB transactions to PADDR
//              0xF00..0xF0C; data-plane traffic targets the legal region.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, ... PSLVERR sticky b5)
//   ERROR_ADDR = 0xF08
//   ERROR_INFO = 0xF0C
//
// DERIVED FROM:
//   - XTP TEST_RESET_004 steps 1-10 — read Table 8 hard-reset defaults, program
//     CTRL=0xF9, induce sticky PSLVERR error at 0x400 (0xDEADBEEF), assert
//     SOFT_RST (CTRL=0xFB), hold 4 cycles, clear (CTRL=0xF9), confirm CTRL
//     preserved while STATUS/ERROR_ADDR cleared, pulse HRESETn to restore
//     CTRL=0x1, then prove resume with 0xCAFEBABE write/read-back at 0x400.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The
//       physical HRESETn pulse (steps 1, 9) is modelled at the stimulus level
//       as a re-read of the reset-default register values; the scoreboard
//       checks address propagation and data integrity over the resulting flow.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_004_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane address (legal region) ─────────────────────────────────────
  localparam logic [31:0] ADDR_DATA  = 32'h0000_0400;  // datapath traffic target

  // ── Control values ────────────────────────────────────────────────────────
  // CTRL_DEFAULT: Table 8 hard-reset value (ENABLE b0=1, rest 0)
  localparam logic [31:0] CTRL_DEFAULT  = 32'h0000_0001;  // hard-reset default
  // CTRL_CONFIG: ENABLE b0, ERR_INT_EN b3, TIMEOUT_VAL b6:4=3'b111, TIMEOUT_EN b7
  localparam logic [31:0] CTRL_CONFIG   = 32'h0000_00F9;  // non-default config
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_00FB;  // + SOFT_RST b1, config kept

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_ERR   = 32'hDEAD_BEEF;  // sticky-error traffic payload
  localparam logic [31:0] DATA_REUSE = 32'hCAFE_BABE;  // post-reset write proof

  function new(string name = "ahb_mst_test_reset_004_seq");
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
    `uvm_info("RST004_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // AHB interface handle (set by the test) used to pulse a mid-test hard reset.
  virtual ahb_mst_if vif;
  logic [31:0] last_rdata;

  task do_hard_reset();
    if (vif == null)
      `uvm_fatal("RST004_SEQ", "vif not set — test must assign seq.vif before start")
    `uvm_info("RST004_SEQ", "Applying HARD RESET (force_rst_n low)", UVM_MEDIUM)
    vif.force_rst_n = 1'b0;
    repeat (8) @(posedge vif.HCLK);
    vif.force_rst_n = 1'b1;
    @(posedge vif.HRESETn);
    repeat (3) @(posedge vif.HCLK);
  endtask

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST004_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST004_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

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
    `uvm_info("RST004_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  task body();
    int unsigned c;

    `uvm_info("RST004_SEQ",
      "Starting TEST_RESET_004: soft-reset vs hard-reset value comparison",
      UVM_MEDIUM)

    // ── T1-T4: post-hard-reset — read Table 8 default register values ─────────
    // CTRL=0x1, STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0
    do_read(REG_CTRL,       "hardrst_ctrl");
    do_read(REG_STATUS,     "hardrst_status");
    do_read(REG_ERROR_ADDR, "hardrst_erraddr");
    do_read(REG_ERROR_INFO, "hardrst_errinfo");

    // ── T5: reconfigure away from defaults — write CTRL=0xF9 ──────────────────
    do_write(REG_CTRL, CTRL_CONFIG, "ctrl_config");
    do_read (REG_CTRL,              "ctrl_config_rb");

    // ── T6: send traffic and induce a sticky PSLVERR error at 0x400 ───────────
    do_write(ADDR_DATA, DATA_ERR, "err_traffic");

    // ── T7: verify pre-soft-reset state — CTRL=0xF9, STATUS sticky, ERROR_ADDR
    do_read(REG_CTRL,       "presoft_ctrl");
    check_rdata(CTRL_CONFIG, "CTRL programmed (pre-soft-reset)");
    do_read(REG_STATUS,     "presoft_status");
    // CTRL_CONFIG has ERR_INT_EN=1, so PSLVERR error => READY|PSLVERR|ERR_INT = 0xA1.
    check_rdata(32'h0000_00A1, "STATUS sticky PSLVERR+ERR_INT (pre-soft-reset)");
    do_read(REG_ERROR_ADDR, "presoft_erraddr");
    check_rdata(ADDR_DATA, "ERROR_ADDR captured (pre-soft-reset)");

    // ── T8: assert SOFT_RST (CTRL=0xFB, SOFT_RST b1=1, config retained) ───────
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");

    // ── T8-T11: hold soft reset N=4 cycles (active/sticky state cleared) ──────
    for (c = 0; c < 4; c++) begin
      do_read(REG_STATUS, $sformatf("status_hold_%0d", c));
    end

    // ── T11: deassert SOFT_RST keeping config (CTRL=0xF9) ─────────────────────
    do_write(REG_CTRL, CTRL_CONFIG, "ctrl_clear_softrst");

    // ── T12: soft-reset result — CTRL=0xF9 PRESERVED, STATUS=0x1, ERROR_ADDR=0x0
    do_read(REG_CTRL,       "postsoft_ctrl");
    // Soft reset clears active/sticky state but PRESERVES the CTRL config.
    check_rdata(CTRL_CONFIG, "CTRL preserved across SOFT_RST");
    do_read(REG_STATUS,     "postsoft_status");
    check_rdata(32'h0000_0001, "STATUS cleared by SOFT_RST");
    do_read(REG_ERROR_ADDR, "postsoft_erraddr");
    check_rdata(32'h0000_0000, "ERROR_ADDR cleared by SOFT_RST");

    // ── T13-T15: apply a full HARD reset (HRESETn) — restores ALL defaults ────
    do_hard_reset();
    do_read(REG_CTRL, "posthard_ctrl");   // expect CTRL=0x1 (hard reset overrides)
    // Unlike soft reset, a hard reset restores CTRL to its Table 8 default 0x01.
    check_rdata(CTRL_DEFAULT, "CTRL restored to default by HARD reset (vs preserved by soft)");

    // ── T16: prove operational after both reset types — write/read 0xCAFEBABE ─
    do_write(ADDR_DATA, DATA_REUSE, "reuse_wr");
    do_read (ADDR_DATA,             "reuse_rd");
    do_read (REG_STATUS,            "final_status");

    `uvm_info("RST004_SEQ", "TEST_RESET_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_004_seq
