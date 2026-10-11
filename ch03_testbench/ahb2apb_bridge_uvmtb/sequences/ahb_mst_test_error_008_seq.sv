// =============================================================================
// FILE: sequences/ahb_mst_test_error_008_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_008
// DESCRIPTION: Stimulus for timeout_window_boundary. Verifies the timeout window
//              boundary condition: a PREADY asserted on the LAST in-window cycle
//              completes cleanly (no error), while a PREADY asserted one cycle
//              PAST the window fires TIMEOUT_ERR:
//                - configure CTRL=0x0000_0091 (ENABLE b0=1, TIMEOUT_VAL=3'b001
//                  small window, TIMEOUT_EN b7=1) — timeout on, small window,
//                - a GOOD write at 0x0000_1000 (0x1111_2222) with PREADY=1
//                  completes OKAY (HRESP=0, HREADY_OUT=1) with a clean STATUS,
//                - in-window case: WRITE at 0x0000_8000 (0x3333_4444) with PREADY
//                  asserted on the last cycle within the window — completes
//                  in-window (HREADY_OUT=1, HRESP=0), no timeout,
//                - out-of-window case: WRITE at 0x0000_9000 (0x5555_6666) with
//                  PREADY held 0 one cycle PAST the window — TIMEOUT_ERR fires
//                  (HRESP=1), STATUS sets TIMEOUT_ERR b6=1 (STATUS bit6 set),
//                - the error log captures ERROR_ADDR=0x0000_9000 and ERROR_INFO
//                  (direction=write, coarse class=timeout),
//                - clear the sticky flag: write STATUS=0x0000_0040 (W1C b6),
//                - recovery: assert SOFT_RST (CTRL=0x0000_0093) then deassert
//                  (CTRL=0x0000_0091) so BUSY clears and the error log returns
//                  to 0 with config preserved,
//                - reconfigure CTRL=0x0000_0091, then a post-recovery good WRITE
//                  at 0x0000_A000 (0x7777_8888) with PREADY=1 in-window proves
//                  data integrity (PADDR=0x0000_A000, PWDATA=0x7777_8888,
//                  HRESP=0) with a clean STATUS log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3,
//                        TIMEOUT_VAL b6:4 cfg, TIMEOUT_EN b7)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_008 steps 1-15 — configure CTRL=0x0000_0091 (timeout on,
//     small window), good write at 0x0000_1000 (0x1111_2222), in-window write
//     at 0x0000_8000 (0x3333_4444) PREADY on last in-window cycle (no error),
//     out-of-window write at 0x0000_9000 (0x5555_6666) PREADY one cycle past
//     window -> TIMEOUT_ERR b6=1, ERROR_ADDR=0x0000_9000, W1C clears flag,
//     SOFT_RST recovery clears log, reconfigure, post-recovery good write at
//     0x0000_A000 (0x7777_8888).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The PREADY
//       stall, timeout-window boundary and error-log capture are modelled in
//       the APB slave / DUT; this sequence drives register and data stimulus
//       only, and the boundary / W1C checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_008_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_008_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good transfers stay inside the valid region. The in-window write completes
  // on the last in-window cycle (no error). The out-of-window write stalls one
  // cycle past the window; with TIMEOUT_EN=1 this provokes a timeout error.
  localparam logic [31:0] ADDR_GOOD_WR1  = 32'h0000_1000;  // good write
  localparam logic [31:0] DATA_GOOD_WR1  = 32'h1111_2222;
  localparam logic [31:0] ADDR_INWIN     = 32'h0000_8000;  // in-window write
  localparam logic [31:0] DATA_INWIN     = 32'h3333_4444;
  localparam logic [31:0] ADDR_TIMEOUT   = 32'h0000_9000;  // out-of-window -> timeout
  localparam logic [31:0] DATA_TIMEOUT   = 32'h5555_6666;
  localparam logic [31:0] ADDR_GOOD_WR2  = 32'h0000_A000;  // post-recovery good wr
  localparam logic [31:0] DATA_GOOD_WR2  = 32'h7777_8888;

  // ── Control / status values ───────────────────────────────────────────────
  // CTRL=0x0091: ENABLE b0=1, SOFT_RST b1=0, ERR_INT_EN b3=0,
  //              TIMEOUT_VAL=3'b001 (small window), TIMEOUT_EN b7=1
  localparam logic [31:0] CTRL_TIMEOUT  = 32'h0000_0091; // enable + timeout, small win
  // CTRL=0x0093: same config but SOFT_RST b1=1 (recovery), then back to 0x0091
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0093; // SOFT_RST asserted

  // ── STATUS W1C value ────────────────────────────────────────────────────────
  localparam logic [31:0] STATUS_W1C_TIMEOUT = 32'h0000_0040; // W1C TIMEOUT_ERR b6

  function new(string name = "ahb_mst_test_error_008_seq");
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
    `uvm_info("ERR008_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

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
    `uvm_info("ERR008_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("ERR008_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("ERR008_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("ERR008_SEQ",
      "Starting TEST_ERROR_008: timeout window boundary",
      UVM_MEDIUM)

    // ── T1: configure CTRL=0x0000_0091 (timeout ON, small window), verify ─────
    do_write(REG_CTRL,   CTRL_TIMEOUT, "ctrl_timeout");
    do_read (REG_CTRL,                 "ctrl_init");

    // ── T2: good WRITE traffic at valid address (PREADY=1) — completes OKAY ───
    do_write(ADDR_GOOD_WR1, DATA_GOOD_WR1, "good_wr1"); // expect HRESP=0, OKAY

    // ── T3: confirm clean STATUS before injection (0x0000_0001) ───────────────
    do_read (REG_STATUS,     "status_clean");

    // ── T4: in-window WRITE at 0x0000_8000 — PREADY on LAST in-window cycle ────
    // Completion occurs in-window: HREADY_OUT=1, HRESP=0 (OKAY), no timeout.
    do_write(ADDR_INWIN, DATA_INWIN, "inwin_wr");

    // ── T5: read STATUS — no error after in-window completion (0x0000_0001) ────
    do_read (REG_STATUS,     "status_inwin");
    check_rdata(32'h0000_0001, "STATUS after in-window write (no timeout)");

    // ── T7: read error log — expect no entry (ERROR_ADDR/INFO = 0) ────────────
    do_read (REG_ERROR_ADDR, "erraddr_inwin");  // expect 0x0000_0000
    check_rdata(32'h0000_0000, "ERROR_ADDR (no error, in-window)");
    do_read (REG_ERROR_INFO, "errinfo_inwin");  // expect 0x0000_0000

    // ── T8: out-of-window WRITE at 0x0000_9000 — PREADY one cycle PAST window ──
    // Window expired before PREADY: TIMEOUT_ERR fires, HRESP=1, HREADY_OUT=1.
    do_write(ADDR_TIMEOUT, DATA_TIMEOUT, "inject_timeout");

    // ── T9: read STATUS — expect TIMEOUT_ERR b6=1 (STATUS bit6 set) ───────────
    do_read (REG_STATUS,     "status_timeout");
    // ERR_INT_EN=0 in CTRL=0x91, so only TIMEOUT_ERR(b6)+READY(b0) => 0x41.
    check_rdata(32'h0000_0041, "STATUS after out-of-window timeout");

    // ── T10: read error log — expect ERROR_ADDR=0x9000, ERROR_INFO captured ───
    do_read (REG_ERROR_ADDR, "erraddr_timeout");  // expect 0x0000_9000
    check_rdata(32'h0000_9000, "ERROR_ADDR captured timeout address");
    do_read (REG_ERROR_INFO, "errinfo_timeout");  // direction=write, class=timeout
    // ERR_TYPE[7:4]=2 (timeout), ERR_WRITE[3]=1 (write), ERR_SIZE[2:0]=2 => 0x2A.
    check_rdata(32'h0000_002A, "ERROR_INFO timeout context (type=timeout,write,word)");

    // ── T11: clear sticky flag — write STATUS=0x0000_0040 (W1C on TIMEOUT_ERR) ─
    do_write(REG_STATUS, STATUS_W1C_TIMEOUT, "w1c_timeout");

    // ── T12: recovery — SOFT_RST assert/deassert, then read error log ─────────
    do_write(REG_CTRL,   CTRL_SOFT_RST, "ctrl_softrst");
    do_write(REG_CTRL,   CTRL_TIMEOUT,  "ctrl_softrst_clr");
    do_read (REG_ERROR_ADDR, "erraddr_recov");     // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");     // expect 0x0000_0000

    // ── T13: reconfigure CTRL=0x0000_0091 and verify STATUS ───────────────────
    do_write(REG_CTRL,   CTRL_TIMEOUT, "ctrl_reconfig");
    do_read (REG_STATUS,               "status_reconfig"); // expect 0x0000_0001

    // ── T14: post-recovery good WRITE at 0x0000_A000 (PREADY=1) — prove path ───
    do_write(ADDR_GOOD_WR2, DATA_GOOD_WR2, "good_wr2"); // PADDR/PWDATA proven, HRESP=0

    // ── T15: PROVE — read STATUS, verify clean data path / error log ──────────
    do_read (REG_STATUS,                    "status_final"); // expect 0x0000_0001

    `uvm_info("ERR008_SEQ", "TEST_ERROR_008 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_008_seq
