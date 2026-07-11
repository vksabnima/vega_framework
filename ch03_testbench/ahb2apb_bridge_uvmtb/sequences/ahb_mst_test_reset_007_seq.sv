// =============================================================================
// FILE: sequences/ahb_mst_test_reset_007_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_007
// DESCRIPTION: Stimulus for hard_reset_clears_sticky_error_state.
//              Verifies that a hard reset clears the sticky STATUS error bits
//              (ERR_INT, TIMEOUT_ERR, PSLVERR, ADDR_ERR) and the captured debug
//              registers ERROR_ADDR / ERROR_INFO.
//              The flow:
//                1. program CTRL=0x9 (ENABLE b0, ERR_INT_EN b3) and read it back,
//                2. prove normal traffic — write/read 0xDEADBEEF at 0x300,
//                3. inject a target error at 0x304 (PSLVERR=1) so the bridge
//                   latches the sticky STATUS error bits and captures the failing
//                   address/context into ERROR_ADDR / ERROR_INFO,
//                4. read STATUS / ERROR_ADDR / ERROR_INFO to confirm the sticky
//                   state is present (STATUS bits PSLVERR + ERR_INT set,
//                   ERROR_ADDR=0x304, ERROR_INFO non-zero),
//                5. (hard reset HRESETn=0 / PRESETn=0 held 10 cycles, released) —
//                   modelled at the stimulus level as a re-read of the Table 8
//                   reset-default register/output values once the reset has
//                   cleared the sticky state,
//                6. verify the sticky state is cleared (STATUS=0x1,
//                   ERROR_ADDR=0x0, ERROR_INFO=0x0),
//                7. reconfigure CTRL=0x9 and prove error-free recovery with a
//                   0xCAFEBABE write/read-back at 0x300 — no residual sticky flags.
//              All register accesses are raw AHB transactions to PADDR
//              0xF00..0xF0C; data-plane traffic targets the legal region.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, PSLVERR sticky b5, ERR_INT sticky b7, ...)
//   ERROR_ADDR = 0xF08
//   ERROR_INFO = 0xF0C
//
// DERIVED FROM:
//   - XTP TEST_RESET_007 steps 1-13 — program CTRL=0x9 (ENABLE, ERR_INT_EN),
//     read back, send 0xDEADBEEF traffic at 0x300, inject a PSLVERR target error
//     at 0x304 (sticky STATUS.PSLVERR + STATUS.ERR_INT set, ERROR_ADDR=0x304,
//     ERROR_INFO captured), read STATUS/ERROR_ADDR/ERROR_INFO to confirm, assert
//     hard reset (HRESETn=0, PRESETn=0) for 10 cycles, release, verify sticky
//     state cleared (STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0), reconfigure
//     CTRL=0x9, then prove error-free recovery with 0xCAFEBABE write/read-back.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The physical
//       HRESETn/PRESETn pulse (steps 7-9) is modelled at the stimulus level as a
//       re-read of the reset-default register/output values; the scoreboard
//       checks address propagation and data integrity over the resulting flow.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_007_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_007_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane addresses (legal region) ───────────────────────────────────
  localparam logic [31:0] ADDR_PROVE = 32'h0000_0300;  // datapath proof target
  localparam logic [31:0] ADDR_ERR   = 32'h0000_0304;  // target-error address

  // ── Control values ────────────────────────────────────────────────────────
  // CTRL_ERR_EN: ENABLE b0=1, ERR_INT_EN b3=1 → 0x9 (error indication enabled)
  localparam logic [31:0] CTRL_ERR_EN  = 32'h0000_0009;

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_TRAFFIC = 32'hDEAD_BEEF;  // pre-error traffic proof
  localparam logic [31:0] DATA_ERR     = 32'h5555_5555;  // error-injection write
  localparam logic [31:0] DATA_REUSE   = 32'hCAFE_BABE;  // post-reset recovery proof

  function new(string name = "ahb_mst_test_reset_007_seq");
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
    `uvm_info("RST007_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // AHB interface handle (set by the test) used to pulse a mid-test hard reset.
  virtual ahb_mst_if vif;
  logic [31:0] last_rdata;

  task do_hard_reset();
    if (vif == null)
      `uvm_fatal("RST007_SEQ", "vif not set — test must assign seq.vif before start")
    `uvm_info("RST007_SEQ", "Applying HARD RESET (force_rst_n low)", UVM_MEDIUM)
    vif.force_rst_n = 1'b0;
    repeat (10) @(posedge vif.HCLK);
    vif.force_rst_n = 1'b1;
    @(posedge vif.HRESETn);
    repeat (3) @(posedge vif.HCLK);
  endtask

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST007_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST007_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
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
    `uvm_info("RST007_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  task body();
    `uvm_info("RST007_SEQ",
      "Starting TEST_RESET_007: hard reset clears sticky error state",
      UVM_MEDIUM)

    // ── T1-T2: program CTRL=0x9 (ENABLE, ERR_INT_EN) and read it back ─────────
    do_write(REG_CTRL, CTRL_ERR_EN, "ctrl_config");
    do_read (REG_CTRL,              "ctrl_config_rb");   // expect 0x9

    // ── T3-T4: prove normal traffic — write/read 0xDEADBEEF at 0x300 ──────────
    do_write(ADDR_PROVE, DATA_TRAFFIC, "traffic_wr");
    do_read (ADDR_PROVE,               "traffic_rd");    // expect 0xDEADBEEF

    // ── T5: inject a target error at 0x304 (PSLVERR=1). The bridge returns
    // HRESP=1 and latches the sticky STATUS error bits (PSLVERR b5, ERR_INT b7)
    // and captures the failing address/context into ERROR_ADDR / ERROR_INFO.
    do_write(ADDR_ERR, DATA_ERR, "err_inject");

    // ── T6-T7: read back the sticky error state to confirm it is set ──────────
    do_read(REG_STATUS,     "preset_status");    // expect PSLVERR+ERR_INT (0xA1)
    check_rdata(32'h0000_00A1, "STATUS sticky PSLVERR+ERR_INT set pre-reset");
    do_read(REG_ERROR_ADDR, "preset_erraddr");   // expect 0x304
    check_rdata(ADDR_ERR, "ERROR_ADDR captured pre-reset");
    do_read(REG_ERROR_INFO, "preset_errinfo");   // expect non-zero

    // ── T8-T18: assert a real hard reset (HRESETn) and release. The sticky
    // STATUS error bits and the captured ERROR_ADDR / ERROR_INFO must clear and
    // all registers return to their Table 8 reset defaults.
    do_hard_reset();

    // ── T19-T21: verify the sticky error state is cleared — STATUS=0x1
    // (READY=1, all error bits 0), ERROR_ADDR=0x0, ERROR_INFO=0x0.
    do_read(REG_STATUS,     "postrst_status");    // expect 0x1
    check_rdata(32'h0000_0001, "STATUS cleared by hard reset");
    do_read(REG_ERROR_ADDR, "postrst_erraddr");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_ADDR cleared by hard reset");
    do_read(REG_ERROR_INFO, "postrst_errinfo");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_INFO cleared by hard reset");

    // ── T22: reconfigure — write CTRL=0x9 (re-enable ENABLE + ERR_INT_EN) ─────
    do_write(REG_CTRL, CTRL_ERR_EN, "ctrl_reenable");

    // ── T23-T24: prove error-free recovery after the sticky-clearing reset —
    // write/read 0xCAFEBABE at 0x300 with no residual sticky flags.
    do_write(ADDR_PROVE, DATA_REUSE, "reuse_wr");
    do_read (ADDR_PROVE,             "reuse_rd");    // expect 0xCAFEBABE

    `uvm_info("RST007_SEQ", "TEST_RESET_007 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_007_seq
