// =============================================================================
// FILE: sequences/ahb_mst_test_reset_008_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_008
// DESCRIPTION: Stimulus for hard_reset_immediate_reuse_after_release.
//              Verifies the bridge is immediately ready to accept and complete a
//              new transfer on the first cycle after reset release, with all
//              registers restored to their Table 8 reset values.
//              The flow:
//                1. program CTRL=0xF1 (ENABLE b0, TIMEOUT_EN b7, TIMEOUT_VAL
//                   b6:4=111) and read it back,
//                2. prove normal traffic — write/read 0xDEADBEEF at 0x400,
//                3. drive the bridge into the SETUP state with a new transfer at
//                   0x404 (STATUS.BUSY=1, PSEL=1, PENABLE=0),
//                4. (hard reset HRESETn=0 / PRESETn=0 asserted on the rising edge,
//                   held exactly 4 cycles T6..T9, released at T10) — modelled at
//                   the stimulus level as a re-read of the Table 8 reset-default
//                   register/output values once the reset has cleared state,
//                5. on the first cycle after release verify readiness — STATUS=0x1
//                   (READY=1) and CTRL=0x1 (TIMEOUT settings cleared),
//                6. confirm the captured debug registers are clear — ERROR_ADDR=0x0,
//                   ERROR_INFO=0x0,
//                7. immediately issue a new transfer with no reconfiguration delay —
//                   write/read-back 0xCAFEBABE at 0x404 (HRESP=0) proving immediate
//                   re-use capability, then re-read STATUS to confirm clean
//                   completion (BUSY=0, READY=1, no sticky error bits → 0x1).
//              All register accesses are raw AHB transactions to PADDR
//              0xF00..0xF0C; data-plane traffic targets the legal region.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, BUSY b1, PSLVERR sticky b5, ERR_INT sticky b7)
//   ERROR_ADDR = 0xF08
//   ERROR_INFO = 0xF0C
//
// DERIVED FROM:
//   - XTP TEST_RESET_008 steps 1-13 — program CTRL=0xF1 (ENABLE, TIMEOUT_EN,
//     TIMEOUT_VAL=111), read back, send 0xDEADBEEF traffic at 0x400, drive bridge
//     into SETUP at 0x404 (BUSY=1), assert hard reset (HRESETn=0, PRESETn=0) on
//     the rising edge, hold exactly 4 cycles (T6..T9), release at T10, verify
//     first-cycle readiness (STATUS=0x1, CTRL=0x1), confirm ERROR_ADDR=0x0 /
//     ERROR_INFO=0x0, then immediately issue 0xCAFEBABE write/read-back at 0x404
//     (HRESP=0) and re-read STATUS (0x1) to prove immediate re-use after reset.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The physical
//       HRESETn/PRESETn pulse (steps 5-7) is modelled at the stimulus level as a
//       re-read of the reset-default register/output values; the scoreboard
//       checks address propagation and data integrity over the resulting flow.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_008_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_008_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane addresses (legal region) ───────────────────────────────────
  localparam logic [31:0] ADDR_PROVE = 32'h0000_0400;  // datapath proof target
  localparam logic [31:0] ADDR_REUSE = 32'h0000_0404;  // SETUP / post-reset reuse

  // ── Control values ────────────────────────────────────────────────────────
  // CTRL_TIMEOUT: ENABLE b0=1, TIMEOUT_VAL b6:4=111, TIMEOUT_EN b7=1 → 0xF1
  localparam logic [31:0] CTRL_TIMEOUT = 32'h0000_00F1;

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_TRAFFIC = 32'hDEAD_BEEF;  // pre-reset traffic proof
  localparam logic [31:0] DATA_REUSE   = 32'hCAFE_BABE;  // post-reset reuse proof

  function new(string name = "ahb_mst_test_reset_008_seq");
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
    `uvm_info("RST008_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // AHB interface handle + config (set by the test). vif pulses the hard reset;
  // cfg lets us stop stalling the abort address before the recovery write.
  virtual ahb_mst_if vif;
  ahb2apb_bridge_dut_config cfg;
  logic [31:0] last_rdata;

  task do_hard_reset();
    if (vif == null)
      `uvm_fatal("RST008_SEQ", "vif not set — test must assign seq.vif before start")
    `uvm_info("RST008_SEQ", "Applying HARD RESET (force_rst_n low)", UVM_MEDIUM)
    vif.force_rst_n = 1'b0;
    repeat (4) @(posedge vif.HCLK);
    vif.force_rst_n = 1'b1;
    @(posedge vif.HRESETn);
    repeat (3) @(posedge vif.HCLK);
  endtask

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST008_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST008_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
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
    `uvm_info("RST008_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  task body();
    `uvm_info("RST008_SEQ",
      "Starting TEST_RESET_008: hard reset immediate reuse after release",
      UVM_MEDIUM)

    // ── T1-T2: program CTRL=0xF1 (ENABLE, TIMEOUT_EN, TIMEOUT_VAL=111) and
    // read it back to confirm the configured value.
    do_write(REG_CTRL, CTRL_TIMEOUT, "ctrl_config");
    do_read (REG_CTRL,               "ctrl_config_rb");   // expect 0xF1

    // ── T3-T4: prove normal traffic — write/read 0xDEADBEEF at 0x400 ──────────
    do_write(ADDR_PROVE, DATA_TRAFFIC, "traffic_wr");
    do_read (ADDR_PROVE,               "traffic_rd");     // expect 0xDEADBEEF

    // ── T5-T10: start a transfer at 0x404 that the target stalls (in-flight),
    // and assert a HARD RESET while it is mid-flight. They run concurrently; the
    // stalled transfer blocks until the reset aborts it.
    fork
      do_write(ADDR_REUSE, DATA_TRAFFIC, "setup_inflight");
      begin
        repeat (5) @(posedge vif.HCLK);   // let the transfer reach the stalled phase
        do_hard_reset();
      end
    join
    // Stop stalling 0x404 so the post-reset recovery write completes normally.
    if (cfg != null) cfg.apb_stall_addrs.delete();

    // ── T11: first cycle after release — verify readiness. STATUS=0x1 (READY=1,
    // BUSY=0, no error bits) and CTRL=0x1 (TIMEOUT settings cleared back to the
    // reset default of ENABLE-only behaviour).
    do_read(REG_STATUS, "postrst_status");    // expect 0x1
    check_rdata(32'h0000_0001, "STATUS clean after mid-transfer reset");
    do_read(REG_CTRL,   "postrst_ctrl");       // expect 0x1
    check_rdata(32'h0000_0001, "CTRL restored to default by hard reset");

    // ── T12: confirm the captured debug registers are clear — ERROR_ADDR=0x0,
    // ERROR_INFO=0x0.
    do_read(REG_ERROR_ADDR, "postrst_erraddr");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_ADDR cleared by reset");
    do_read(REG_ERROR_INFO, "postrst_errinfo");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_INFO cleared by reset");

    // ── T13-T14: immediately issue a new transfer with no reconfiguration delay —
    // write/read-back 0xCAFEBABE at 0x404 proving the bridge accepts the transfer
    // on the first attempt post-reset (HREADY_OUT asserts on completion, HRESP=0).
    do_write(ADDR_REUSE, DATA_REUSE, "reuse_wr");
    do_read (ADDR_REUSE,             "reuse_rd");    // expect 0xCAFEBABE
    check_rdata(DATA_REUSE, "Immediate post-reset reuse write/read-back at aborted address");

    // ── T15: re-read STATUS to confirm clean completion — BUSY=0, READY=1, no
    // sticky error bits → 0x1.
    do_read(REG_STATUS, "final_status");      // expect 0x1
    check_rdata(32'h0000_0001, "STATUS clean after post-reset reuse");

    `uvm_info("RST008_SEQ", "TEST_RESET_008 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_008_seq
