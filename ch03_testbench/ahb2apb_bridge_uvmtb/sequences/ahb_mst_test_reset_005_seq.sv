// =============================================================================
// FILE: sequences/ahb_mst_test_reset_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_005
// DESCRIPTION: Stimulus for hard_reset_during_idle_register_defaults.
//              Verifies that asserting a hard reset while the bridge is idle
//              returns all outputs and registers to their documented Table 8
//              reset values, and that the bridge recovers cleanly afterwards.
//              The flow:
//                1. program a non-default CTRL (0xF9) and read it back,
//                2. send data-plane traffic (write/read 0xDEADBEEF at 0x100),
//                3. (bridge idle) apply a full hard reset (pulse HRESETn /
//                   PRESETn) — modelled at the stimulus level as a re-read of
//                   the Table 8 default register values,
//                4. read all registers and confirm defaults
//                   (CTRL=0x1, STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0),
//                5. reconfigure CTRL=0x1 (re-enable) and prove operational with
//                   a 0xCAFEBABE write/read-back — full functional recovery.
//              All register accesses are raw AHB transactions to PADDR
//              0xF00..0xF0C; data-plane traffic targets the legal region.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, BUSY ..., PSLVERR sticky b5)
//   ERROR_ADDR = 0xF08
//   ERROR_INFO = 0xF0C
//
// DERIVED FROM:
//   - XTP TEST_RESET_005 steps 1-13 — program CTRL=0xF9, read back, send
//     0xDEADBEEF traffic at 0x100, assert hard reset (HRESETn=0, PRESETn=0) for
//     8 cycles while idle, release, verify outputs and all registers at Table 8
//     defaults (CTRL=0x1, STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0),
//     reconfigure CTRL=0x1, then prove recovery with 0xCAFEBABE write/read-back.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The
//       physical HRESETn/PRESETn pulse (steps 6-8) is modelled at the stimulus
//       level as a re-read of the reset-default register values; the scoreboard
//       checks address propagation and data integrity over the resulting flow.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_005_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane address (legal region) ─────────────────────────────────────
  localparam logic [31:0] ADDR_DATA = 32'h0000_0100;  // datapath traffic target

  // ── Control values ────────────────────────────────────────────────────────
  // CTRL_DEFAULT: Table 8 hard-reset value (ENABLE b0=1, rest 0)
  localparam logic [31:0] CTRL_DEFAULT = 32'h0000_0001;  // hard-reset default
  // CTRL_CONFIG: ENABLE b0, ERR_INT_EN b3, TIMEOUT_VAL b6:4=3'b111, TIMEOUT_EN b7
  localparam logic [31:0] CTRL_CONFIG  = 32'h0000_00F9;  // non-default config

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_TRAFFIC = 32'hDEAD_BEEF;  // pre-reset traffic proof
  localparam logic [31:0] DATA_REUSE   = 32'hCAFE_BABE;  // post-reset recovery proof

  function new(string name = "ahb_mst_test_reset_005_seq");
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
    `uvm_info("RST005_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // AHB interface handle (set by the test) used to pulse a mid-test hard reset.
  virtual ahb_mst_if vif;
  logic [31:0] last_rdata;

  task do_hard_reset();
    if (vif == null)
      `uvm_fatal("RST005_SEQ", "vif not set — test must assign seq.vif before start")
    `uvm_info("RST005_SEQ", "Applying HARD RESET (force_rst_n low)", UVM_MEDIUM)
    vif.force_rst_n = 1'b0;
    repeat (8) @(posedge vif.HCLK);
    vif.force_rst_n = 1'b1;
    @(posedge vif.HRESETn);
    repeat (3) @(posedge vif.HCLK);
  endtask

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST005_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST005_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
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
    `uvm_info("RST005_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  task body();
    `uvm_info("RST005_SEQ",
      "Starting TEST_RESET_005: hard reset during idle — register defaults",
      UVM_MEDIUM)

    // ── T1-T2: program a non-default CTRL (0xF9) and read it back ─────────────
    do_write(REG_CTRL, CTRL_CONFIG, "ctrl_config");
    do_read (REG_CTRL,              "ctrl_config_rb");   // expect 0xF9

    // ── T3-T4: send data-plane traffic — write/read 0xDEADBEEF at 0x100 ───────
    do_write(ADDR_DATA, DATA_TRAFFIC, "traffic_wr");
    do_read (ADDR_DATA,               "traffic_rd");     // expect 0xDEADBEEF

    // ── T5: bridge is idle (no pending transfer) — apply a real hard reset ────
    do_hard_reset();

    // ── T15-T16: verify all registers at documented reset values ──────────────
    // CTRL=0x1, STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0 — prior CTRL=0xF9
    // cleared back to 0x1 by the hard reset.
    do_read(REG_CTRL,       "posthard_ctrl");      // expect 0x1
    check_rdata(32'h0000_0001, "CTRL restored to reset default by hard reset");
    do_read(REG_STATUS,     "posthard_status");    // expect 0x1
    check_rdata(32'h0000_0001, "STATUS restored to reset default");
    do_read(REG_ERROR_ADDR, "posthard_erraddr");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_ADDR cleared by hard reset");
    do_read(REG_ERROR_INFO, "posthard_errinfo");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_INFO cleared by hard reset");

    // ── T17: reconfigure — write CTRL=0x1 (re-enable) ─────────────────────────
    do_write(REG_CTRL, CTRL_DEFAULT, "ctrl_reenable");

    // ── T18-T19: prove full functional recovery — write/read 0xCAFEBABE ───────
    do_write(ADDR_DATA, DATA_REUSE, "reuse_wr");
    do_read (ADDR_DATA,             "reuse_rd");    // expect 0xCAFEBABE

    `uvm_info("RST005_SEQ", "TEST_RESET_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_005_seq
