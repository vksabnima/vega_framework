// =============================================================================
// FILE: sequences/ahb_mst_test_error_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_005
// DESCRIPTION: Stimulus for timeout_error_basic_detection. Verifies a timeout
//              error is detected, captured in STATUS, and logged when PREADY is
//              never asserted within the programmed observation window:
//                - configure CTRL=0x0000_00F1 (ENABLE, ERR_INT_EN=0,
//                  TIMEOUT_VAL=3'b111, TIMEOUT_EN=1), verify STATUS clean,
//                - a GOOD write at a valid address (0x0000_1000, 0xDEAD_BEEF)
//                  completes with HRESP=0 and a clean error log, then
//                - a write at 0x0000_2000 (0xCAFE_0001) with the target stalled
//                  (PREADY held 0) lets the timeout window (TIMEOUT_VAL=7)
//                  expire, asserting HRESP=1 with HREADY_OUT released, setting
//                  the sticky TIMEOUT_ERR (STATUS b6) while ERR_INT (b7) stays 0
//                  (ERR_INT_EN=0), and capturing ERROR_ADDR=0x0000_2000 with
//                  ERROR_INFO recording direction=write / class=timeout,
//                - W1C clear of TIMEOUT_ERR (b6),
//                - soft-reset recovery (config preserved, ERROR_ADDR/ERROR_INFO
//                  cleared, BUSY=0),
//                - reconfigure CTRL=0x0000_00F1, then a post-recovery good write
//                  at 0x0000_3000 returns 0x1234_5678 with a clean log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_EN b4, TIMEOUT_VAL b7:5)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_005 steps 1-15 — configure CTRL=0x0000_00F1, good write at
//     0x0000_1000 (0xDEAD_BEEF), inject timeout write at 0x0000_2000 with PREADY
//     held 0 past the TIMEOUT_VAL=7 window, capture TIMEOUT_ERR + ERROR_ADDR=
//     0x0000_2000 + write-direction context (ERR_INT stays 0), W1C clear of b6,
//     soft-reset recover (config preserved, error log cleared), reconfigure,
//     post-recovery good write at 0x0000_3000 returns 0x1234_5678.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PREADY
//       stall and timeout-window counting are modelled in the APB slave / DUT;
//       this sequence drives register and data stimulus only, and the timeout /
//       recovery checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_005_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good transfers stay inside the valid region. The injected request targets a
  // valid address but the target stalls (PREADY=0) to provoke the timeout.
  localparam logic [31:0] ADDR_GOOD_WR1  = 32'h0000_1000;  // good write
  localparam logic [31:0] DATA_GOOD_WR1  = 32'hDEAD_BEEF;
  localparam logic [31:0] ADDR_TIMEOUT   = 32'h0000_2000;  // stalled write -> timeout
  localparam logic [31:0] DATA_TIMEOUT   = 32'hCAFE_0001;
  localparam logic [31:0] ADDR_GOOD_WR2  = 32'h0000_3000;  // post-recovery good wr
  localparam logic [31:0] DATA_GOOD_WR2  = 32'h1234_5678;

  // ── Control / status values ───────────────────────────────────────────────
  // CTRL=0x00F1: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=0,
  //              TIMEOUT_EN b4=1, TIMEOUT_VAL b7:5=3'b111
  localparam logic [31:0] CTRL_TIMEOUT_EN = 32'h0000_00F1;  // enable + timeout cfg
  // CTRL=0x00F3: same config but SOFT_RST b1=1 (recovery), then back to 0x00F1
  localparam logic [31:0] CTRL_SOFT_RST   = 32'h0000_00F3;  // SOFT_RST asserted
  localparam logic [31:0] STATUS_W1C       = 32'h0000_0040;  // W1C TIMEOUT_ERR b6

  function new(string name = "ahb_mst_test_error_005_seq");
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
    `uvm_info("ERR005_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // Last captured read-back value / response, for self-checks.
  logic [31:0] last_rdata;
  logic        last_resp;

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
    `uvm_info("ERR005_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  // ── Helper: assert the last read-back value ───────────────────────────────
  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR005_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR005_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR005_SEQ",
      "Starting TEST_ERROR_005: timeout error basic detection + recovery",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_00F1 (timeout enabled), verify ─────────────
    do_write(REG_CTRL,   CTRL_TIMEOUT_EN, "ctrl_timeout_en");
    do_read (REG_CTRL,                    "ctrl_init");

    // ── T2: good WRITE traffic at valid address — must complete cleanly ───────
    do_write(ADDR_GOOD_WR1, DATA_GOOD_WR1, "good_wr1");

    // ── T3: confirm clean STATUS before injection (0x0000_0001) ───────────────
    do_read (REG_STATUS,     "status_clean");

    // ── T4: inject timeout — write to 0x0000_2000 with target stalled ─────────
    do_write(ADDR_TIMEOUT, DATA_TIMEOUT, "inject_timeout");

    // ── T5..Tn+1: timeout window expires; observe error indication ────────────
    // T7: STATUS — expect TIMEOUT_ERR b6=1 (sticky), ERR_INT b7=0, READY b0=1
    do_read (REG_STATUS,     "status_timeout");
    // READY(b0)=1 + TIMEOUT_ERR(b6)=1, ERR_INT(b7)=0 (ERR_INT_EN not set) => 0x41.
    check_rdata(32'h0000_0041, "STATUS after timeout (TIMEOUT_ERR set)");

    // ── T8: read captured error log ───────────────────────────────────────────
    do_read (REG_ERROR_ADDR, "erraddr_capt");   // expect 0x0000_2000
    check_rdata(32'h0000_2000, "ERROR_ADDR captured timeout address");
    do_read (REG_ERROR_INFO, "errinfo_capt");   // direction=write, class=timeout
    // ERR_TYPE[7:4]=2 (timeout), ERR_WRITE[3]=1, ERR_SIZE[2:0]=2 (word) => 0x2A.
    check_rdata(32'h0000_002A, "ERROR_INFO timeout context (type=timeout,write,word)");

    // ── T10: W1C clear of sticky TIMEOUT_ERR (b6) ─────────────────────────────
    do_write(REG_STATUS, STATUS_W1C, "status_w1c");

    // ── T11: read STATUS to verify clear (expect 0x0000_0001) ─────────────────
    do_read (REG_STATUS,             "status_postclr");
    check_rdata(32'h0000_0001, "STATUS after W1C clear of TIMEOUT_ERR");

    // ── T12: recovery via soft reset — assert SOFT_RST then deassert ──────────
    do_write(REG_CTRL, CTRL_SOFT_RST,   "ctrl_softrst");
    do_write(REG_CTRL, CTRL_TIMEOUT_EN, "ctrl_softrst_clr");

    // ── T13: read error log after recovery — expect cleared by reset ──────────
    do_read (REG_ERROR_ADDR, "erraddr_recov");
    do_read (REG_ERROR_INFO, "errinfo_recov");

    // ── T14: reconfigure CTRL=0x0000_00F1 and verify STATUS ───────────────────
    do_write(REG_CTRL,   CTRL_TIMEOUT_EN, "ctrl_reconfig");
    do_read (REG_STATUS,                  "status_reconfig");

    // ── T15: post-recovery good WRITE at 0x0000_3000 — prove integrity ────────
    do_write(ADDR_GOOD_WR2, DATA_GOOD_WR2, "good_wr2");
    do_read (REG_STATUS,                    "status_final");

    `uvm_info("ERR005_SEQ", "TEST_ERROR_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_005_seq
