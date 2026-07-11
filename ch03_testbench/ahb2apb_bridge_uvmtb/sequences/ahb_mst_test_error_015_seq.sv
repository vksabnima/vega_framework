// =============================================================================
// FILE: sequences/ahb_mst_test_error_015_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_ERROR_015
// DESCRIPTION: Stimulus for address_error_class_capture_and_recovery.
//              Verifies the address-error class is distinct from a target
//              PSLVERR path: an unsupported/invalid HADDR generates HRESP=1,
//              sets STATUS.ADDR_ERR (b4) sticky, captures the offending address
//              in ERROR_ADDR, is W1C-clearable, and is fully recoverable via
//              SOFT_RST:
//                - configure CTRL=0x0000_0001 (ENABLE b0=1), verify clean
//                  STATUS=0x0000_0001,
//                - good WRITE at valid 0x0000_1000 (HWDATA=0x0000_5555,
//                  PSLVERR=0) completes OKAY (PSEL=1, PENABLE=1 active phase
//                  reached, HREADY_OUT=1, HRESP=0),
//                - read STATUS — confirm clean (ADDR_ERR b4=0),
//                - inject address error: WRITE at unsupported 0xDEAD_0000
//                  (HWDATA=0x0000_1111) — bridge flags invalid-address, no valid
//                  target access driven (PSEL stays 0 / no valid PENABLE phase),
//                - verify error detected: HRESP=1 asserted within the error
//                  response window (T4..T6), HREADY_OUT=1 at window close,
//                - check interrupt: with ERR_INT_EN=0 no external interrupt;
//                  STATUS.ERR_INT (b7)=0, STATUS.ADDR_ERR (b4) sticky=1,
//                - read error log: STATUS=0x0000_0011 (ADDR_ERR b4=1, READY b0=1),
//                - read error info: ERROR_ADDR=0xDEAD_0000 (captured invalid
//                  address), ERROR_INFO encodes direction=write + address-error
//                  class,
//                - clear sticky: W1C bit 4 — write STATUS=0x0000_0010,
//                - verify cleared: STATUS=0x0000_0001 (ADDR_ERR cleared, READY=1),
//                - recovery: soft reset CTRL=0x0000_0003 (ENABLE + SOFT_RST b1)
//                  clears active state + sticky flags + error log,
//                - read error log after recovery: STATUS=0x0000_0001,
//                  ERROR_ADDR=0x0000_0000, ERROR_INFO=0x0000_0000,
//                - reconfigure CTRL=0x0000_0001,
//                - post-recovery good READ at valid 0x0000_1008 returns
//                  PRDATA=0x0BAD_F00D with HRESP=0 and a clean error log,
//                - PROVE: compare HRDATA to 0x0BAD_F00D and re-read STATUS /
//                  ERROR_ADDR to confirm a clean error log.
//              All accesses are raw AHB transactions. Register accesses target
//              the control/status block at PADDR 0xF00..0xF0C.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE b0, SOFT_RST b1, ERR_INT_EN b3, ...)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5,
//                        TIMEOUT_ERR b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured failing address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_ERROR_015 steps 1-15 — configure CTRL=0x0000_0001, good write at
//     0x0000_1000, confirm clean STATUS, inject invalid HADDR=0xDEAD_0000 ->
//     HRESP=1 with no valid PSEL/PENABLE target access, STATUS.ADDR_ERR sticky
//     (STATUS=0x0000_0011), ERROR_ADDR=0xDEAD_0000, W1C bit 4
//     (STATUS=0x0000_0010 -> STATUS=0x0000_0001), SOFT_RST CTRL=0x0000_0003
//     clears log (STATUS=0x0000_0001, ERR regs 0), reconfigure CTRL=0x0000_0001,
//     post-recovery good read at 0x0000_1008 returns 0x0BAD_F00D with a clean log.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The address-
//       error detection, HRESP timing, error response window, sticky behavior,
//       and error-log capture are modelled in the DUT; this sequence drives
//       register and data stimulus only, and the response/timing/sticky/W1C/
//       soft-reset checks live in the scoreboard.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_error_015_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_error_015_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Transfer addresses / data ──────────────────────────────────────────────
  // Good traffic targets valid APB addresses and completes OKAY. The injected
  // write targets an unsupported/invalid address, which the DUT flags as an
  // address-error class: HRESP=1 with no valid target access, ADDR_ERR sticky,
  // and ERROR_ADDR captures the offending address.
  localparam logic [31:0] ADDR_GOOD_WR   = 32'h0000_1000;  // good write (valid)
  localparam logic [31:0] DATA_GOOD_WR   = 32'h0000_5555;  // expected PWDATA
  localparam logic [31:0] ADDR_BAD       = 32'hDEAD_0000;  // invalid-address injection
  localparam logic [31:0] DATA_BAD       = 32'h0000_1111;  // injected write data
  localparam logic [31:0] ADDR_GOOD_RD   = 32'h0000_1008;  // post-recovery read (valid)
  localparam logic [31:0] DATA_GOOD_RD   = 32'h0BAD_F00D;  // expected PRDATA / HRDATA

  // ── Control values ──────────────────────────────────────────────────────────
  // CTRL=0x0001: ENABLE b0=1, ERR_INT_EN b3=0 (interrupt disabled — clean baseline)
  localparam logic [31:0] CTRL_ENABLE   = 32'h0000_0001; // enable, no err interrupt
  // CTRL=0x0003: ENABLE b0=1 + SOFT_RST b1=1 (recovery)
  localparam logic [31:0] CTRL_SOFT_RST = 32'h0000_0003; // SOFT_RST + config preserved

  // ── STATUS W1C value — clear ADDR_ERR b4 ───────────────────────────────────
  localparam logic [31:0] STATUS_W1C_ADDR_ERR = 32'h0000_0010; // W1C ADDR_ERR b4

  function new(string name = "ahb_mst_test_error_015_seq");
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
    `uvm_info("ERR015_SEQ",
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
    `uvm_info("ERR015_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("ERR015_SEQ",
      "Starting TEST_ERROR_015: address-error class capture and recovery (HRESP=1, ADDR_ERR sticky, ERROR_ADDR, recover)",
      UVM_MEDIUM)

    // ── Step 1: configure CTRL=0x0000_0001 (ENABLE=1), verify clean ────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_read (REG_STATUS,              "status_init");        // expect 0x0000_0001

    // ── Step 2: good WRITE at valid 0x0000_1000 (PSLVERR=0) — completes OKAY ───
    // PSEL=1, PENABLE=1 active phase reached, HREADY_OUT=1, HRESP=0.
    do_write(ADDR_GOOD_WR, DATA_GOOD_WR, "good_wr");          // PWDATA=0x0000_5555

    // ── Step 3: read STATUS — confirm clean (no ADDR_ERR) ──────────────────────
    do_read (REG_STATUS,     "status_clean");                // expect 0x0000_0001

    // ── Step 4: inject address error — WRITE at invalid 0xDEAD_0000 ────────────
    // Bridge flags invalid-address; no valid target access driven (PSEL stays 0
    // / no valid PENABLE active phase for the invalid range).
    do_write(ADDR_BAD, DATA_BAD, "inject_addr_err");

    // ── Step 5: verify error detected — HRESP=1 within error response window ────
    // HRESP=1 asserted (T4..T6), HREADY_OUT=1 at window close; PSEL=0/PENABLE=0.
    do_read (REG_STATUS,     "status_addr_err");             // ADDR_ERR set sticky

    // ── Step 6: check interrupt — ERR_INT_EN=0 so no external interrupt ─────────
    // STATUS.ERR_INT b7=0; STATUS.ADDR_ERR b4 sticky=1.
    do_read (REG_STATUS,     "status_errint");               // expect ERR_INT b7=0

    // ── Step 7: read error log type — STATUS=0x0000_0011 (ADDR_ERR=1, READY=1) ──
    do_read (REG_STATUS,     "status_errclass");             // expect 0x0000_0011

    // ── Step 8: read error info — ERROR_ADDR=0xDEAD_0000, ERROR_INFO dir=write ──
    do_read (REG_ERROR_ADDR, "erraddr_addr_err");            // expect 0xDEAD_0000
    do_read (REG_ERROR_INFO, "errinfo_addr_err");            // direction=write, address-error

    // ── Step 9: clear sticky — W1C bit 4 write STATUS=0x0000_0010 ──────────────
    do_write(REG_STATUS, STATUS_W1C_ADDR_ERR, "w1c_addr_err");

    // ── Step 10: verify cleared — read STATUS (0x0000_0001) ────────────────────
    do_read (REG_STATUS,     "status_cleared");              // expect 0x0000_0001

    // ── Step 11: recovery — soft reset CTRL=0x0000_0003 (SOFT_RST+ENABLE) ───────
    // SOFT_RST clears active state + sticky flags + error log; config preserved.
    do_write(REG_CTRL,   CTRL_SOFT_RST, "ctrl_softrst");

    // ── Step 12: read error log after recovery — STATUS=0x0001, ERR regs clear ─
    do_read (REG_STATUS,     "status_recov");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_recov");               // expect 0x0000_0000
    do_read (REG_ERROR_INFO, "errinfo_recov");               // expect 0x0000_0000

    // ── Step 13: reconfigure — re-enable CTRL=0x0000_0001 ──────────────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_reenable");
    do_read (REG_STATUS,              "status_reenable");    // expect 0x0000_0001

    // ── Step 14: post-recovery good READ at valid 0x0000_1008 -> 0x0BAD_F00D ───
    do_read (ADDR_GOOD_RD,   "good_rd");                     // expect HRDATA=0x0BAD_F00D, HRESP=0

    // ── Step 15: PROVE — re-read error log: STATUS/ERR_ADDR clean ──────────────
    do_read (REG_STATUS,     "status_final");                // expect 0x0000_0001
    do_read (REG_ERROR_ADDR, "erraddr_final");               // expect 0x0000_0000

    `uvm_info("ERR015_SEQ", "TEST_ERROR_015 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_error_015_seq
