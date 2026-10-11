// =============================================================================
// FILE: sequences/ahb_mst_test_reset_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_001
// DESCRIPTION: Stimulus for soft_reset_clears_active_transfer_state.
//              Drives a configure -> active write traffic -> soft-reset assert
//              (while transfer in flight) -> hold -> STATUS read-back ->
//              reconfigure -> re-use proof flow, all as raw AHB transactions.
//              Register accesses target the control/status block at
//              PADDR 0xF00..0xF0C; data-plane traffic targets the legal
//              region 0x0000_0000-0x0000_FFFF.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL   = 0xF00  (ENABLE bit0, SOFT_RST bit1, TIMEOUT_EN bit2)
//   STATUS = 0xF04  (READY b0, BUSY b1, sticky error bits[7:4])
//
// DERIVED FROM:
//   - XTP TEST_RESET_001 steps 1-10 — configure (CTRL=0x1), active write at
//     0x100 (0xDEADBEEF), assert SOFT_RST (CTRL=0x3) while in-flight, hold 4
//     cycles, read STATUS (expect 0x1), reconfigure (CTRL=0x1), then prove
//     re-use: write 0xCAFEBABE at 0x100 and read it back.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_001_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL   = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS = 32'h0000_0F04;

  // ── Data-plane address (legal region) ─────────────────────────────────────
  localparam logic [31:0] ADDR_DATA  = 32'h0000_0100;  // active transfer target

  // ── Control values ────────────────────────────────────────────────────────
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0001;  // ENABLE=1, SOFT_RST=0
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003;  // ENABLE=1 + SOFT_RST=1

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_INFLIGHT = 32'hDEAD_BEEF;  // active write payload
  localparam logic [31:0] DATA_REUSE    = 32'hCAFE_BABE;  // post-reset write proof

  function new(string name = "ahb_mst_test_reset_001_seq");
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
    `uvm_info("RST001_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // ── Helper: drive a single word READ transaction ──────────────────────────
  logic [31:0] last_rdata;
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
    `uvm_info("RST001_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST001_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST001_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    int unsigned c;

    `uvm_info("RST001_SEQ",
      "Starting TEST_RESET_001: soft-reset clears active transfer state",
      UVM_MEDIUM)

    // ── T1: configure CTRL (ENABLE=1), confirm STATUS read-back ──────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");

    // ── T2-T4: active write traffic — transfer goes in-flight (BUSY) ─────────
    do_write(ADDR_DATA, DATA_INFLIGHT, "inflight_wr");

    // ── T5: assert SOFT_RST while transfer is in ACTIVE/WAITING state ────────
    do_write(REG_CTRL, CTRL_SOFT_RST, "ctrl_softrst");

    // ── T5-T8: hold soft reset for N=4 cycles (active state cleared) ─────────
    for (c = 0; c < 4; c++) begin
      do_read(REG_STATUS, $sformatf("status_hold_%0d", c));
    end

    // ── T9: read STATUS — expect 0x1 (READY=1, BUSY=0, no sticky errors) ─────
    do_read (REG_STATUS, "status_postrst");
    check_rdata(32'h0000_0001, "STATUS after SOFT_RST (active state cleared)");

    // ── T11: reconfigure — clear SOFT_RST, keep ENABLE=1 ─────────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reconfig");
    do_read (REG_STATUS,              "status_reconfig");

    // ── T12: prove re-use — write 0xCAFEBABE then read it back ───────────────
    do_write(ADDR_DATA, DATA_REUSE, "reuse_wr");
    do_read (ADDR_DATA,             "reuse_rd");

    `uvm_info("RST001_SEQ", "TEST_RESET_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_001_seq
