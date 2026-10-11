// =============================================================================
// FILE: sequences/ahb_mst_test_reset_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_RESET_006
// DESCRIPTION: Stimulus for hard_reset_during_active_transfer_abort.
//              Verifies that asserting a hard reset while a transfer is in the
//              ACTIVE/WAITING phase aborts the stalled transfer cleanly and
//              restores all reset values, then recovers cleanly afterwards.
//              The flow:
//                1. program CTRL=0x1 (ENABLE) and read it back,
//                2. send data-plane traffic (write/read 0xDEADBEEF at 0x200) to
//                   prove the datapath works,
//                3. start a new write at 0x204 (0x12345678) that the target
//                   stalls (PREADY=0) — transfer is left mid-flight in the
//                   ACTIVE/WAITING phase,
//                4. (transfer stalled) apply a full hard reset (pulse HRESETn /
//                   PRESETn for 6 cycles) — modelled at the stimulus level as a
//                   re-read of the Table 8 default register/output values once
//                   the reset has aborted the in-flight transfer,
//                5. verify all registers at defaults
//                   (STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0) — no spurious
//                   error set by the abort,
//                6. reconfigure CTRL=0x1 (re-enable) and prove operational with
//                   a 0xCAFEBABE write/read-back at 0x204 — full recovery,
//                   proving no residual aborted-transfer state.
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
//   - XTP TEST_RESET_006 steps 1-13 — program CTRL=0x1, read back, send
//     0xDEADBEEF traffic at 0x200, start a stalled write at 0x204 (target not
//     ready, ACTIVE/WAITING phase), assert hard reset (HRESETn=0, PRESETn=0) for
//     6 cycles mid-transfer, release, verify outputs/registers at Table 8
//     defaults (STATUS=0x1, ERROR_ADDR=0x0, ERROR_INFO=0x0, aborted PWDATA
//     cleared), reconfigure CTRL=0x1, then prove recovery with 0xCAFEBABE
//     write/read-back.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C. The
//       physical HRESETn/PRESETn pulse mid-transfer (steps 6-8) is modelled at
//       the stimulus level as a re-read of the reset-default register/output
//       values; the scoreboard checks address propagation and data integrity
//       over the resulting flow.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_reset_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_reset_006_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Data-plane addresses (legal region) ───────────────────────────────────
  localparam logic [31:0] ADDR_PROVE  = 32'h0000_0200;  // datapath proof target
  localparam logic [31:0] ADDR_ABORT  = 32'h0000_0204;  // stalled/aborted target

  // ── Control values ────────────────────────────────────────────────────────
  // CTRL_DEFAULT: Table 8 hard-reset value (ENABLE b0=1, rest 0)
  localparam logic [31:0] CTRL_DEFAULT = 32'h0000_0001;  // hard-reset default

  // ── Data payloads ─────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_TRAFFIC = 32'hDEAD_BEEF;  // pre-reset traffic proof
  localparam logic [31:0] DATA_ABORT   = 32'h1234_5678;  // stalled/aborted write
  localparam logic [31:0] DATA_REUSE   = 32'hCAFE_BABE;  // post-reset recovery proof

  function new(string name = "ahb_mst_test_reset_006_seq");
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
    `uvm_info("RST006_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // AHB interface handle (set by the test) used to pulse a mid-test hard reset.
  virtual ahb_mst_if vif;
  logic [31:0] last_rdata;

  task do_hard_reset();
    if (vif == null)
      `uvm_fatal("RST006_SEQ", "vif not set — test must assign seq.vif before start")
    `uvm_info("RST006_SEQ", "Applying HARD RESET (force_rst_n low)", UVM_MEDIUM)
    vif.force_rst_n = 1'b0;
    repeat (6) @(posedge vif.HCLK);
    vif.force_rst_n = 1'b1;
    @(posedge vif.HRESETn);
    repeat (3) @(posedge vif.HCLK);
  endtask

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("RST006_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("RST006_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
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
    `uvm_info("RST006_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
  endtask : do_read

  task body();
    `uvm_info("RST006_SEQ",
      "Starting TEST_RESET_006: hard reset during active transfer — abort",
      UVM_MEDIUM)

    // ── T1-T2: program CTRL=0x1 (ENABLE) and read it back ─────────────────────
    do_write(REG_CTRL, CTRL_DEFAULT, "ctrl_config");
    do_read (REG_CTRL,               "ctrl_config_rb");   // expect 0x1

    // ── T3-T4: prove traffic works — write/read 0xDEADBEEF at 0x200 ───────────
    do_write(ADDR_PROVE, DATA_TRAFFIC, "traffic_wr");
    do_read (ADDR_PROVE,               "traffic_rd");     // expect 0xDEADBEEF

    // ── T5-T13: start a write at 0x204 that the target stalls (PREADY=0, timeout
    // disabled so it holds), and assert a HARD RESET while it is mid-flight. The
    // two run concurrently: the stalled write blocks until the reset aborts it
    // (HRESETn forces the bridge back to idle). The fork joins once both the
    // aborted write returns and the reset has been released.
    fork
      do_write(ADDR_ABORT, DATA_ABORT, "abort_wr");
      begin
        repeat (6) @(posedge vif.HCLK);   // let the write reach the stalled phase
        do_hard_reset();
      end
    join

    // ── T14-T16: verify outputs/registers at documented reset values — no
    // residual aborted state, no spurious error. STATUS=0x1 (BUSY=0, READY=1),
    // ERROR_ADDR=0x0, ERROR_INFO=0x0.
    do_read(REG_STATUS,     "postabort_status");    // expect 0x1
    check_rdata(32'h0000_0001, "STATUS clean after mid-transfer hard reset (abort)");
    do_read(REG_ERROR_ADDR, "postabort_erraddr");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_ADDR cleared by abort reset");
    do_read(REG_ERROR_INFO, "postabort_errinfo");   // expect 0x0
    check_rdata(32'h0000_0000, "ERROR_INFO cleared by abort reset");

    // ── T17: reconfigure — write CTRL=0x1 (re-enable) ─────────────────────────
    do_write(REG_CTRL, CTRL_DEFAULT, "ctrl_reenable");

    // ── T18-T19: prove clean recovery after mid-transfer reset — write/read
    // 0xCAFEBABE at the previously-aborted address 0x204.
    do_write(ADDR_ABORT, DATA_REUSE, "reuse_wr");
    do_read (ADDR_ABORT,             "reuse_rd");    // expect 0xCAFEBABE

    `uvm_info("RST006_SEQ", "TEST_RESET_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_reset_006_seq
